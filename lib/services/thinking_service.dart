import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../models/project.dart';
import '../models/miko_response.dart';
import 'formatter_service.dart';
import 'miko_service.dart';
import 'llm_client.dart';
import 'local_llm_service.dart';

/// The thinking-partner engine, tiered for cost:
///
///  1. **Per-note analysis** runs on Miko's *local* brain (on-device Gemma) when
///     it's installed — free, offline, private. If it isn't installed or fails,
///     we degrade to rule-based structuring. The cloud is NEVER used per-note,
///     so everyday rambling can't run up an API bill.
///  2. **Deep dives** ("Ask Miko: pull the TAM/SAM/SOM", "fact-check this") are
///     the only paid path — they need live web data, so they hit the cloud
///     ([LlmClient]) with web search, and only when the user explicitly asks.
class ThinkingService {
  /// Build a thinking document from a transcript. Local-first; never cloud.
  static Future<Note> analyze({
    required String transcript,
    required int durationSeconds,
    required List<Project> projects,
    required List<Note> history,
    required bool mikoEnabled,
  }) async {
    if (LocalLlmService.instance.isInstalled) {
      try {
        return await _localAnalyze(
          transcript: transcript,
          durationSeconds: durationSeconds,
          projects: projects,
          history: history,
          mikoEnabled: mikoEnabled,
        );
      } catch (e) {
        debugPrint('ThinkingService: local analyze failed, falling back ($e)');
      }
    }
    return _ruleBased(
      transcript: transcript,
      durationSeconds: durationSeconds,
      projects: projects,
      history: history,
      mikoEnabled: mikoEnabled,
    );
  }

  /// Ask Miko to dig deeper — the only cloud path. Needs a key + internet.
  static Future<Insight> deepDive({
    required Note note,
    required String query,
    required String apiKey,
  }) async {
    final client = LlmClient(apiKey);
    final system =
        'You are Miko, a rigorous thinking partner inside a voice-note app. '
        'The user has been thinking about: "${note.title}". '
        'Their note summary: "${note.summary.isEmpty ? note.keyQuote : note.summary}". '
        'They are asking you to dig deeper. Use web search to find REAL, current '
        'figures, facts, and evidence. Be concrete and numeric where possible, and '
        'honest about uncertainty — never invent a statistic. '
        'Respond ONLY with a JSON object, no markdown fences, of the form: '
        '{"kind":"stat"|"support"|"correction","text":"2-4 sentence answer with concrete numbers","source":"the single most useful source URL, or empty string"}';
    final raw = await client.complete(
      system: system,
      userText: query,
      webSearch: true,
      maxTokens: 2048,
    );
    final map = _extractJson(raw);
    if (map != null) {
      return Insight(
        kind: _safeInsightKind(map['kind'] as String?),
        text: (map['text'] as String?)?.trim() ?? raw,
        source: (map['source'] as String?)?.trim() ?? '',
      );
    }
    return Insight(kind: 'stat', text: raw, source: '');
  }

  // ── Local LLM path ────────────────────────────────────────────────────────

  static Future<Note> _localAnalyze({
    required String transcript,
    required int durationSeconds,
    required List<Project> projects,
    required List<Note> history,
    required bool mikoEnabled,
  }) async {
    final prompt = '${_analyzeSystem(mikoEnabled)}\n\n'
        '${_analyzeUser(transcript, history)}';
    final raw = await LocalLlmService.instance.complete(prompt: prompt);
    final map = _extractJson(raw);
    if (map == null) throw const FormatException('Local analysis: no JSON');
    return _buildNoteFromAnalysis(
      map: map,
      transcript: transcript,
      durationSeconds: durationSeconds,
      projects: projects,
      mikoEnabled: mikoEnabled,
    );
  }

  static String _analyzeSystem(bool mikoEnabled) {
    final mikoBlock = mikoEnabled
        ? 'Then act as a sharp thinking partner. In "insights", surface up to 3 of '
            'the most valuable interventions. Each has a "kind": '
            '"support" (a fact/principle that backs the thinking), '
            '"correction" (something the user likely got wrong), '
            '"contradiction" (clashes with their OWN earlier notes — see RECENT NOTES), '
            '"question" (a sharp hole worth probing), '
            '"stat" (a concrete figure you are confident about). '
            'Be honest; never invent statistics — if unsure, make it a question. '
            'If you have nothing genuinely useful to add, use an empty array.'
        : 'Leave "insights" as an empty array.';
    return 'You are Miko, the thinking partner inside Ramble. The user rambles out '
        'loud; you turn it into a structured thinking document. '
        'Respond with ONLY a single minified JSON object — no prose, no code fences. Schema:\n'
        '{"title":"punchy, <=60 chars",'
        '"context":"ONE of: University|Startup|Work|Personal|Research|Health|Finance|Creative|Other",'
        '"type_index":0-6 (0 idea,1 task,2 meeting,3 study,4 reflection,5 research,6 feedback),'
        '"summary":"2-3 sentence TL;DR of what they thought",'
        '"arc":[{"kind":"start|point|turn|landing","text":"one beat of their thinking"}],'
        '"tags":["3-6 lowercase topic tags"],'
        '"tasks":["concrete to-dos they mentioned"],'
        '"questions":["open questions raised"],'
        '"insights":[{"kind":"...","text":"...","source":"optional url"}]}\n'
        'The "arc" traces HOW their thinking moved: where they started, points '
        'touched, any turns, where they landed. $mikoBlock';
  }

  static String _analyzeUser(String transcript, List<Note> history) {
    final recent = history
        .take(12)
        .where((n) => n.summary.isNotEmpty || n.title.isNotEmpty);
    final historyBlock = recent.isEmpty
        ? '(none yet)'
        : recent
            .map((n) =>
                '- [${n.context.isEmpty ? n.type.label : n.context}] ${n.title}: ${n.summary.isEmpty ? n.keyQuote : n.summary}')
            .join('\n');
    return 'RECENT NOTES (for spotting contradictions/connections):\n'
        '$historyBlock\n\n'
        'TRANSCRIPT OF WHAT I JUST SAID:\n"$transcript"';
  }

  static Note _buildNoteFromAnalysis({
    required Map<String, dynamic> map,
    required String transcript,
    required int durationSeconds,
    required List<Project> projects,
    required bool mikoEnabled,
  }) {
    final type = NoteTypeX.fromIndex((map['type_index'] as num?)?.toInt() ?? 0);
    final tags = _stringList(map['tags']);
    final taskTexts = _stringList(map['tasks']);
    final questionTexts = _stringList(map['questions']);

    final items = <ExtractedItem>[
      for (final t in taskTexts) ExtractedItem(kind: 'task', text: t),
      for (final q in questionTexts) ExtractedItem(kind: 'question', text: q),
    ];

    final arc = <ThoughtPoint>[
      for (final a in (map['arc'] as List? ?? []))
        if (a is Map) ThoughtPoint.fromJson(Map<String, dynamic>.from(a)),
    ];

    final insights = mikoEnabled
        ? <Insight>[
            for (final i in (map['insights'] as List? ?? []))
              if (i is Map)
                Insight(
                  kind: _safeInsightKind(i['kind'] as String?),
                  text: (i['text'] as String?)?.trim() ?? '',
                  source: (i['source'] as String?)?.trim() ?? '',
                ),
          ].where((i) => i.text.isNotEmpty).toList()
        : <Insight>[];

    final title = _clip((map['title'] as String?)?.trim(), transcript);
    final summary = (map['summary'] as String?)?.trim() ?? '';

    return Note(
      id: 'n_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      type: type,
      projectId: _assignProject(transcript, projects),
      keyQuote: summary.isNotEmpty ? summary : title,
      fields: {},
      rawTranscript: transcript,
      tags: tags,
      items: items,
      reminders: const [],
      confidence: 0.9,
      createdAt: DateTime.now(),
      durationSeconds: durationSeconds,
      summary: summary,
      context: (map['context'] as String?)?.trim() ?? '',
      arc: arc,
      insights: insights,
      analyzed: true,
    );
  }

  // ── Rule-based fallback (no model installed) ───────────────────────────────

  static Future<Note> _ruleBased({
    required String transcript,
    required int durationSeconds,
    required List<Project> projects,
    required List<Note> history,
    required bool mikoEnabled,
  }) async {
    final note = await FormatterService.buildNote(
      transcript: transcript,
      durationSeconds: durationSeconds,
      projects: projects,
    );

    final sentences = transcript
        .split(RegExp(r'[.!?\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    note.summary = note.keyQuote;
    note.context = '';
    if (sentences.isNotEmpty) {
      note.arc = [
        ThoughtPoint(kind: 'start', text: sentences.first),
        if (sentences.length > 2)
          ThoughtPoint(kind: 'point', text: sentences[sentences.length ~/ 2]),
        if (sentences.length > 1)
          ThoughtPoint(kind: 'landing', text: sentences.last),
      ];
    }

    if (mikoEnabled) {
      final miko = MikoService.react(note, history);
      if (!miko.isSilent) {
        note.insights = [
          Insight(kind: _mikoTriggerToKind(miko.trigger), text: miko.message),
        ];
      }
    }
    note.analyzed = false;
    return note;
  }

  static String _mikoTriggerToKind(MikoTrigger t) {
    switch (t) {
      case MikoTrigger.contradiction:
        return 'contradiction';
      case MikoTrigger.repeatedTask:
        return 'question';
      case MikoTrigger.connection:
      case MikoTrigger.recurringTheme:
      case MikoTrigger.staleReactivated:
      case MikoTrigger.firstInProject:
      case MikoTrigger.none:
        return 'support';
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Map<String, dynamic>? _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      return jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static List<String> _stringList(dynamic v) {
    if (v is! List) return [];
    return v
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String _safeInsightKind(String? k) {
    const valid = {'support', 'correction', 'contradiction', 'question', 'stat'};
    final lower = (k ?? '').toLowerCase();
    return valid.contains(lower) ? lower : 'support';
  }

  static String _clip(String? title, String transcript) {
    var t = (title ?? '').trim();
    if (t.isEmpty) {
      t = transcript.trim();
      if (t.isEmpty) return 'Untitled ramble';
    }
    if (t.length > 60) {
      t = t.substring(0, 60).trim();
      final sp = t.lastIndexOf(' ');
      if (sp > 20) t = t.substring(0, sp);
    }
    return t;
  }

  static String _assignProject(String transcript, List<Project> projects) {
    if (projects.isEmpty) return '';
    final lower = transcript.toLowerCase();
    String? best;
    int bestLen = 0;
    for (final p in projects) {
      final name = p.name.toLowerCase();
      if (name.isNotEmpty && lower.contains(name) && name.length > bestLen) {
        best = p.id;
        bestLen = name.length;
      }
    }
    return best ?? '';
  }
}
