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

/// The core note document. Persisted to Hive as JSON via [toJson]/[fromJson].
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
  });

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
      );
}
