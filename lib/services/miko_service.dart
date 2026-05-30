import '../models/note.dart';
import '../models/miko_response.dart';

class MikoService {
  /// Analyze a freshly-saved note against prior history. Returns at most one
  /// response. history is all OTHER notes (excluding `note`), newest first.
  /// Returns MikoResponse.silent when nothing is notable — Miko never spams.
  static MikoResponse react(Note note, List<Note> history) {
    if (history.isEmpty) {
      // Check if this is first in its project
      return _checkFirstInProject(note, history);
    }

    // Trigger priority order: highest to lowest.

    // 1. CONTRADICTION (highest priority)
    final contradiction = _checkContradiction(note, history);
    if (!contradiction.isSilent) return contradiction;

    // 2. REPEATED TASK
    final repeatedTask = _checkRepeatedTask(note, history);
    if (!repeatedTask.isSilent) return repeatedTask;

    // 3. CONNECTION
    final connection = _checkConnection(note, history);
    if (!connection.isSilent) return connection;

    // 4. RECURRING THEME
    final recurringTheme = _checkRecurringTheme(note, history);
    if (!recurringTheme.isSilent) return recurringTheme;

    // 5. STALE REACTIVATED
    final staleReactivated = _checkStaleReactivated(note, history);
    if (!staleReactivated.isSilent) return staleReactivated;

    // 6. FIRST IN PROJECT
    final firstInProject = _checkFirstInProject(note, history);
    if (!firstInProject.isSilent) return firstInProject;

    // 7. Otherwise silent
    return MikoResponse.silent;
  }

  /// CONTRADICTION: find an older note in the SAME project whose content
  /// negates this one. Detect via stance keywords (strong opinion) vs.
  /// negation/opposite decision on same topic.
  static MikoResponse _checkContradiction(Note note, List<Note> history) {
    if (note.projectId.isEmpty) return MikoResponse.silent;

    // Extract stance from current note: look for strong keywords
    final currentStance = _extractStance(note);
    if (currentStance == null) return MikoResponse.silent;

    // Look for older notes in same project with conflicting stance
    for (final oldNote in history) {
      if (oldNote.projectId != note.projectId) continue;

      final oldStance = _extractStance(oldNote);
      if (oldStance == null) continue;

      // Check if stances conflict on a shared topic
      if (currentStance.topic == oldStance.topic &&
          currentStance.isOppositeOf(oldStance)) {
        final datePhrase = _phraseDate(oldNote.createdAt, note.createdAt);
        return MikoResponse(
          trigger: MikoTrigger.contradiction,
          message:
              'wait. on $datePhrase you leaned the other way on ${currentStance.topic}. these conflict — which is it? 👀',
          relatedNoteId: oldNote.id,
        );
      }
    }

    return MikoResponse.silent;
  }

  /// REPEATED TASK: if this note has a task whose text is similar to tasks
  /// in 2+ older notes, this is the 3rd+ time.
  static MikoResponse _checkRepeatedTask(Note note, List<Note> history) {
    final tasks = note.tasks;
    if (tasks.isEmpty) return MikoResponse.silent;

    for (final task in tasks) {
      final normalized = normalize(task.text);
      int matchCount = 0;

      for (final oldNote in history) {
        final oldTasks = oldNote.tasks;
        for (final oldTask in oldTasks) {
          if (_isSimilarTask(normalized, normalize(oldTask.text))) {
            matchCount++;
            if (matchCount >= 2) {
              // Found in 2+ older notes = 3rd+ time
              final shortTask = task.text.length > 40
                  ? '${task.text.substring(0, 37)}...'
                  : task.text;
              return MikoResponse(
                trigger: MikoTrigger.repeatedTask,
                message:
                    "this is the 3rd time you've noted '$shortTask'. what's actually blocking you?",
              );
            }
          }
        }
      }
    }

    return MikoResponse.silent;
  }

  /// CONNECTION: if this note shares 2+ significant tags/keywords with a
  /// specific older note (and isn't a duplicate), flag it.
  static MikoResponse _checkConnection(Note note, List<Note> history) {
    if (note.tags.isEmpty) return MikoResponse.silent;

    for (final oldNote in history) {
      if (oldNote.id == note.id) continue;

      final overlap = _countTagOverlap(note.tags, oldNote.tags);
      if (overlap >= 2) {
        final sharedTopic = _findSharedTopic(note.tags, oldNote.tags);
        final datePhrase = _phraseDate(oldNote.createdAt, note.createdAt);
        return MikoResponse(
          trigger: MikoTrigger.connection,
          message:
              "this sounds like something you said on $datePhrase about ${sharedTopic ?? 'this'}. you're circling it — want to see them together?",
          relatedNoteId: oldNote.id,
        );
      }
    }

    return MikoResponse.silent;
  }

  /// RECURRING THEME: if note.type == reflection and one of its tags
  /// appears in 4+ older reflection notes.
  static MikoResponse _checkRecurringTheme(Note note, List<Note> history) {
    if (note.type != NoteType.reflection || note.tags.isEmpty) {
      return MikoResponse.silent;
    }

    for (final tag in note.tags) {
      int reflectionCount = 0;

      for (final oldNote in history) {
        if (oldNote.type == NoteType.reflection &&
            oldNote.tags.contains(tag)) {
          reflectionCount++;
        }
      }

      if (reflectionCount >= 4) {
        return MikoResponse(
          trigger: MikoTrigger.recurringTheme,
          message:
              "you've circled '$tag' ${reflectionCount + 1} times now. might be worth sitting with it.",
        );
      }
    }

    return MikoResponse.silent;
  }

  /// STALE REACTIVATED: if note.projectId != '' and the most recent OTHER
  /// note in that project is >14 days older than this note.
  static MikoResponse _checkStaleReactivated(Note note, List<Note> history) {
    if (note.projectId.isEmpty) return MikoResponse.silent;

    // Find most recent other note in same project
    Note? mostRecent;
    for (final oldNote in history) {
      if (oldNote.projectId == note.projectId) {
        mostRecent = oldNote;
        break; // history is sorted newest first
      }
    }

    if (mostRecent == null) return MikoResponse.silent;

    final daysSince = note.createdAt.difference(mostRecent.createdAt).inDays;
    if (daysSince > 14) {
      return MikoResponse(
        trigger: MikoTrigger.staleReactivated,
        message:
            'first note in this project in $daysSince days. good to be back on it.',
      );
    }

    return MikoResponse.silent;
  }

  /// FIRST IN PROJECT: if note.projectId != '' and there are ZERO other
  /// notes in that project.
  static MikoResponse _checkFirstInProject(Note note, List<Note> history) {
    if (note.projectId.isEmpty) return MikoResponse.silent;

    // Check if any note in history shares this projectId
    for (final oldNote in history) {
      if (oldNote.projectId == note.projectId) {
        return MikoResponse.silent;
      }
    }

    return MikoResponse(
      trigger: MikoTrigger.firstInProject,
      message: "ooh, a new thread. let's see where this one goes. ⭐",
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  /// Normalize text: lowercase, trim, collapse whitespace, strip punctuation.
  static String normalize(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Convert a DateTime to a friendly phrase relative to now.
  /// Within 7 days: weekday lowercase (e.g. "tuesday").
  /// Else: "mmm d" format (e.g. "mar 4").
  static String _phraseDate(DateTime oldDate, DateTime now) {
    final daysDiff = now.difference(oldDate).inDays;

    if (daysDiff <= 7) {
      const weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      return weekdays[oldDate.weekday - 1];
    }

    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    return '${months[oldDate.month - 1]} ${oldDate.day}';
  }

  /// Count overlapping tags between two lists (case-insensitive).
  static int _countTagOverlap(List<String> tags1, List<String> tags2) {
    final normalized1 = tags1.map((t) => t.toLowerCase()).toSet();
    final normalized2 = tags2.map((t) => t.toLowerCase()).toSet();
    return normalized1.intersection(normalized2).length;
  }

  /// Find the first shared tag between two lists (for messaging).
  static String? _findSharedTopic(List<String> tags1, List<String> tags2) {
    final normalized1 = tags1.map((t) => t.toLowerCase()).toSet();
    for (final tag in tags2) {
      if (normalized1.contains(tag.toLowerCase())) {
        return tag;
      }
    }
    return null;
  }

  /// Check if two task texts are similar (normalized containment either direction).
  static bool _isSimilarTask(String norm1, String norm2) {
    // Exact match after normalization
    if (norm1 == norm2) return true;
    // One contains the other (fuzzy match)
    if (norm1.length > norm2.length) {
      return norm1.contains(norm2);
    } else {
      return norm2.contains(norm1);
    }
  }

  /// Extract stance from a note's content (title, key quote, fields, tags).
  /// Returns a Stance object if found, null otherwise.
  static Stance? _extractStance(Note note) {
    final allText = _gatherText(note);
    final normalized = normalize(allText);

    // Strong stance keywords (affirmative)
    const strongKeywords = [
      'definitely',
      'going with',
      'decided',
      'we should',
      'must',
      'absolutely',
      'commit to'
    ];

    // Negation/opposite keywords
    const negationKeywords = [
      'not',
      'won\'t',
      'won\'t',
      'instead of',
      'drop',
      'abandon',
      'reject',
      'avoid',
    ];

    // Check for strong stance
    final hasStrong = strongKeywords.any((kw) => normalized.contains(normalize(kw)));
    if (!hasStrong) return null;

    // Extract topic (first meaningful tag or key phrase from title)
    final topic = note.tags.isNotEmpty
        ? note.tags.first.toLowerCase()
        : _extractKeyPhrase(note.title);

    // Check if old notes with opposite stance on same topic exist
    final hasNegation = negationKeywords.any((kw) => normalized.contains(normalize(kw)));

    return Stance(topic: topic, isAffirmative: !hasNegation);
  }

  /// Gather all text from a note for analysis.
  static String _gatherText(Note note) {
    final parts = [
      note.title,
      note.keyQuote,
      ...note.tags,
      ...note.fields.values,
    ];
    return parts.where((s) => s.isNotEmpty).join(' ');
  }

  /// Extract a key phrase from note title for topic identification.
  static String _extractKeyPhrase(String title) {
    // Simple heuristic: first 1-3 words
    final words = title.split(' ');
    return words.take(3).join(' ').toLowerCase();
  }
}

/// Helper class to represent a detected stance (topic + affirmative/negation).
class Stance {
  final String topic;
  final bool isAffirmative;

  Stance({required this.topic, required this.isAffirmative});

  bool isOppositeOf(Stance other) {
    // Same topic, opposite polarity
    return topic == other.topic && isAffirmative != other.isAffirmative;
  }
}

/// Extension on String to expose normalize for tests.
extension NormalizerExt on String {
  String normalized() => MikoService.normalize(this);
}
