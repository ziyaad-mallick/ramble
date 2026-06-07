import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../models/project.dart';
import '../models/miko_response.dart';
import 'formatter_service.dart';
import 'miko_service.dart';
import 'llm_client.dart';

/// The thinking-partner engine. Turns a raw transcript into a structured
/// *thinking document*: summary, the arc of the thought (where you started →
/// points → turns → where you landed), an auto life-context tag, and — when
/// Miko is on — interventions that support, correct, contradict, or question
/// your thinking, plus on-demand web-researched stats.
///
/// With an API key it uses Claude (the real brain). Without one it degrades
/// gracefully to the rule-based [FormatterService] + [MikoService] so the app
/// still produces a clean document offline.
class ThinkingService {
  /// Build a thinking document from a transcript.
  static Future<Note> analyze({
    required String transcript,
    required int durationSeconds,
    required List<Project> projects,
    required List<Note> history,
    required String apiKey,
    required bool mikoEnabled,
  }) async {
    final client = LlmClient(apiKey);
    if (client.hasKey) {
      try {
        return await _llmAnalyze(
          client: client,
          transcript: transcript,
          durationSeconds: durationSeconds,
          projects: projects,
          history: history,
          mikoEnabled: mikoEnabled,
        );
      } catch (e) {
        debugPrint('ThinkingService: LLM failed, falling back ($e)');
        // fall through to rule-based
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

  /// Ask Miko to dig deeper — "pull TAM/SAM/SOM", "find holes in this", etc.
  /// Uses live web search for real figures. Returns one [Insight] to append to
  /// the document, or throws [LlmException] (caller shows the error).
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
    // Model didn't return clean JSON — keep the prose as a stat insight.
    return Insight(kind: 'stat', text: raw, source: '');
  }

  // ── LLM path ────────────────────────────────────────────────────────────

  static Future<Note> _llmAnalyze({
    required LlmClient client,
    required String transcript,
    required int durationSeconds,
    required List<Project> projects,
    required List<Note> history,
    required bool mikoEnabled,
  }) async {
    final mikoBlock = mikoEnabled
        ? 'Then act as a sharp thinking partner. In "insights", surface 1-4 of '
            'the most valuable interventions. Each has a "kind": '
            '"support" (a fact/principle that backs the thinking), '
            '"correction" (something the user got factually wrong), '
            '"contradiction" (clashes with their OWN earlier notes — see RECENT NOTES), '
            '"question" (a sharp hole worth probing), '
            '"stat" (a concrete figure from your knowledge — add a "source" if you can). '
            'Be honest and specific. Never invent statistics; if unsure, mark it a question. '
            'If you have nothing genuinely useful to add, return an empty insights array.'
        : 'Leave "insights" as an empty array.';

    final recent = history.take(15).where((n) => n.summary.isNotEmpty || n.title.isNotEmpty);
    final historyBlock = recent.isEmpty
        ? '(none yet)'
        : recent
            .map((n) =>
                '- [${n.context.isEmpty ? n.type.label : n.context}] ${n.title}: ${n.summary.isEmpty ? n.keyQuote : n.summary}')
            .join('\n');

    final system =
        'You are Miko, the thinking partner inside Ramble, a voice-note app. The user '
        'rambles out loud; you turn it into a structured thinking document. '
        'Respond ONLY with a single JSON object — no prose, no markdown fences. Schema:\n'
        '{\n'
        '  "title": "punchy title, max 60 chars",\n'
        '  "context": "ONE of: University | Startup | Work | Personal | Research | Health | Finance | Creative | Other",\n'
        '  "type_index": 0-6 (0 idea, 1 task, 2 meeting, 3 study, 4 reflection, 5 research, 6 feedback),\n'
        '  "summary": "2-3 sentence TL;DR of what they actually thought",\n'
        '  "arc": [ {"kind":"start|point|turn|landing","text":"one beat of their thinking"} ],\n'
        '  "tags": ["3-6 lowercase topic tags"],\n'
        '  "tasks": ["any concrete to-dos they mentioned"],\n'
        '  "questions": ["open questions they raised or you noticed"],\n'
        '  "insights": [ {"kind":"...","text":"...","source":"optional url"} ]\n'
        '}\n'
        'The "arc" should trace HOW their thinking moved: where they started, the '
        'points they touched, any turns/changes of mind, and where they landed. '
        '$mikoBlock';

    final userText = 'RECENT NOTES (for spotting contradictions/connections):\n'
        '$historyBlock\n\n'
        'TRANSCRIPT OF WHAT I JUST SAID:\n"$transcript"';

    final raw = await client.complete(
      system: system,
      userText: userText,
      maxTokens: 4096,
    );
    final map = _extractJson(raw);
    if (map == null) throw const LlmException('Could not parse analysis JSON');

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
      confidence: 1.0,
      createdAt: DateTime.now(),
      durationSeconds: durationSeconds,
      summary: summary,
      context: (map['context'] as String?)?.trim() ?? '',
      arc: arc,
      insights: insights,
      analyzed: true,
    );
  }

  // ── Rule-based fallback ───────────────────────────────────────────────────

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

    // A lightweight arc + summary from the transcript so the doc view still works.
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

  /// Match the transcript against project names (longest match wins), else Inbox.
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
