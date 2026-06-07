import '../theme/ramble_theme.dart';

/// The 7 intent types from the PRD's Intent Detection Engine. Order matters:
/// index is persisted, so only append new types at the end.
enum NoteType { idea, task, meeting, study, reflection, research, feedback }

extension NoteTypeX on NoteType {
  /// Human label for badges/headers.
  String get label {
    switch (this) {
      case NoteType.idea:
        return 'Idea';
      case NoteType.task:
        return 'Task';
      case NoteType.meeting:
        return 'Meeting Debrief';
      case NoteType.study:
        return 'Study';
      case NoteType.reflection:
        return 'Reflection';
      case NoteType.research:
        return 'Research';
      case NoteType.feedback:
        return 'Feedback';
    }
  }

  RambleNoteTone get tone {
    switch (this) {
      case NoteType.idea:
        return RambleNoteTone.idea;
      case NoteType.task:
        return RambleNoteTone.task;
      case NoteType.meeting:
        return RambleNoteTone.meeting;
      case NoteType.study:
        return RambleNoteTone.study;
      case NoteType.reflection:
        return RambleNoteTone.reflection;
      case NoteType.research:
        return RambleNoteTone.research;
      case NoteType.feedback:
        return RambleNoteTone.feedback;
    }
  }

  /// The ordered field keys this intent type renders in the structured doc view.
  /// Keys map into [Note.fields]. Defined here so the formatter and the doc view
  /// agree on exactly which fields exist per type.
  List<String> get fieldKeys {
    switch (this) {
      case NoteType.idea:
        return ['Problem', 'Direction', 'Who it\'s for', 'Validate first', 'Effort'];
      case NoteType.task:
        return ['Action', 'Why it matters', 'Deadline', 'Dependencies', 'Delegatable'];
      case NoteType.meeting:
        return ['People', 'Decisions', 'Actions', 'Open questions', 'What changed'];
      case NoteType.study:
        return ['Concept', 'Explanation', 'Example', 'Still unclear', 'Source'];
      case NoteType.reflection:
        return ['Insight', 'Trigger', 'Tension', 'Next step', 'Pattern'];
      case NoteType.research:
        return ['Topic', 'Key points', 'Source', 'Relevance', 'Follow-up'];
      case NoteType.feedback:
        return ['Subject', 'Working', 'Broken', 'Suggestions', 'Verdict'];
    }
  }

  static NoteType fromIndex(int i) =>
      (i >= 0 && i < NoteType.values.length) ? NoteType.values[i] : NoteType.idea;
}

/// An extracted, tappable item from a note (task / question / decision / person).
class ExtractedItem {
  final String kind; // 'task' | 'question' | 'decision' | 'person'
  final String text;
  bool done;

  ExtractedItem({required this.kind, required this.text, this.done = false});

  Map<String, dynamic> toJson() => {'kind': kind, 'text': text, 'done': done};

  factory ExtractedItem.fromJson(Map<String, dynamic> j) => ExtractedItem(
        kind: j['kind'] as String,
        text: j['text'] as String,
        done: (j['done'] as bool?) ?? false,
      );
}

/// A reminder detected in the note.
class Reminder {
  final String text;
  final DateTime? dateTime;

  Reminder({required this.text, this.dateTime});

  Map<String, dynamic> toJson() =>
      {'text': text, 'dateTime': dateTime?.toIso8601String()};

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        text: j['text'] as String,
        dateTime:
            j['dateTime'] != null ? DateTime.tryParse(j['dateTime'] as String) : null,
      );
}

/// One beat in the arc of a ramble — how the thinking moved.
/// kind ∈ 'start' (where you began) | 'point' (a point you touched) |
/// 'turn' (a pivot/change of mind) | 'landing' (where you ended up).
class ThoughtPoint {
  final String kind;
  final String text;

  ThoughtPoint({required this.kind, required this.text});

  Map<String, dynamic> toJson() => {'kind': kind, 'text': text};

  factory ThoughtPoint.fromJson(Map<String, dynamic> j) => ThoughtPoint(
        kind: (j['kind'] as String?) ?? 'point',
        text: (j['text'] as String?) ?? '',
      );
}

/// Miko's intervention on your thinking — the thinking-partner layer.
/// kind ∈ 'support' (a fact/stat that backs you up) | 'correction' (something
/// you got wrong) | 'contradiction' (clashes with your own earlier thinking) |
/// 'question' (a hole worth probing) | 'stat' (a figure, ideally sourced).
/// [source] is an optional citation/URL ('' when none).
class Insight {
  final String kind;
  final String text;
  final String source;

  Insight({required this.kind, required this.text, this.source = ''});

  Map<String, dynamic> toJson() =>
      {'kind': kind, 'text': text, 'source': source};

  factory Insight.fromJson(Map<String, dynamic> j) => Insight(
        kind: (j['kind'] as String?) ?? 'support',
        text: (j['text'] as String?) ?? '',
        source: (j['source'] as String?) ?? '',
      );
}

/// The core thinking document. Persisted to Hive as JSON via [toJson]/[fromJson].
/// Fields added for the thinking-partner pivot (summary, context, arc, insights,
/// analyzed) all default empty/false so notes written before the pivot still decode.
class Note {
  final String id;
  String title;
  NoteType type;
  String projectId; // '' = Inbox (unassigned)

  /// The single most important sentence, surfaced prominently (Key Quote).
  String keyQuote;

  /// Structured fields keyed by [NoteTypeX.fieldKeys]. Missing keys render empty.
  Map<String, String> fields;

  final String rawTranscript; // never overwritten
  List<String> tags;
  List<ExtractedItem> items;
  List<Reminder> reminders;

  /// Intent detection confidence 0..1.
  double confidence;

  final DateTime createdAt;
  final int durationSeconds;

  // ── Thinking-partner layer (S-rework) ──────────────────────────────────────
  /// Miko's TL;DR of what you thought.
  String summary;

  /// Auto-classified life context — e.g. 'University', 'Startup', 'Personal'.
  String context;

  /// The arc of the ramble: where you started → points → turns → where you landed.
  List<ThoughtPoint> arc;

  /// Miko's interventions (supports, corrections, contradictions, questions, stats).
  /// Only populated when Miko is enabled.
  List<Insight> insights;

  /// True once the LLM thinking pass has enriched this note (vs rule-based only).
  bool analyzed;

  Note({
    required this.id,
    required this.title,
    required this.type,
    required this.projectId,
    required this.keyQuote,
    required this.fields,
    required this.rawTranscript,
    required this.tags,
    required this.items,
    required this.reminders,
    required this.confidence,
    required this.createdAt,
    required this.durationSeconds,
    this.summary = '',
    this.context = '',
    List<ThoughtPoint>? arc,
    List<Insight>? insights,
    this.analyzed = false,
  })  : arc = arc ?? [],
        insights = insights ?? [];

  List<ExtractedItem> get tasks => items.where((i) => i.kind == 'task').toList();
  List<ExtractedItem> get questions =>
      items.where((i) => i.kind == 'question').toList();
  List<ExtractedItem> get decisions =>
      items.where((i) => i.kind == 'decision').toList();
  List<ExtractedItem> get people => items.where((i) => i.kind == 'person').toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.index,
        'projectId': projectId,
        'keyQuote': keyQuote,
        'fields': fields,
        'rawTranscript': rawTranscript,
        'tags': tags,
        'items': items.map((e) => e.toJson()).toList(),
        'reminders': reminders.map((e) => e.toJson()).toList(),
        'confidence': confidence,
        'createdAt': createdAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'summary': summary,
        'context': context,
        'arc': arc.map((e) => e.toJson()).toList(),
        'insights': insights.map((e) => e.toJson()).toList(),
        'analyzed': analyzed,
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: j['title'] as String,
        type: NoteTypeX.fromIndex(j['type'] as int),
        projectId: (j['projectId'] as String?) ?? '',
        keyQuote: (j['keyQuote'] as String?) ?? '',
        fields: Map<String, String>.from(j['fields'] as Map? ?? {}),
        rawTranscript: (j['rawTranscript'] as String?) ?? '',
        tags: List<String>.from(j['tags'] as List? ?? []),
        items: (j['items'] as List? ?? [])
            .map((e) => ExtractedItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        reminders: (j['reminders'] as List? ?? [])
            .map((e) => Reminder.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.parse(j['createdAt'] as String),
        durationSeconds: (j['durationSeconds'] as int?) ?? 0,
        summary: (j['summary'] as String?) ?? '',
        context: (j['context'] as String?) ?? '',
        arc: (j['arc'] as List? ?? [])
            .map((e) => ThoughtPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        insights: (j['insights'] as List? ?? [])
            .map((e) => Insight.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        analyzed: (j['analyzed'] as bool?) ?? false,
      );
}
