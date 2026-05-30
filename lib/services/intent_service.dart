import '../models/note.dart';

class IntentService {
  /// Classify a transcript into one of 7 NoteTypes with a confidence 0..1.
  /// Uses rule-based keyword/pattern matching. Returns (type, confidence).
  static (NoteType, double) detect(String transcript) {
    if (transcript.isEmpty) {
      return (NoteType.reflection, 0.4);
    }

    final lower = transcript.toLowerCase();
    final scores = <NoteType, int>{
      NoteType.idea: 0,
      NoteType.task: 0,
      NoteType.meeting: 0,
      NoteType.study: 0,
      NoteType.reflection: 0,
      NoteType.research: 0,
      NoteType.feedback: 0,
    };

    // IDEA signals
    final ideaPatterns = [
      'what if',
      'idea',
      'imagine',
      'we could',
      'opportunity',
      'problem is',
      'build a',
      'concept'
    ];
    for (final p in ideaPatterns) {
      scores[NoteType.idea] = scores[NoteType.idea]! + lower.split(p).length - 1;
    }

    // TASK signals
    final taskPatterns = [
      'i need to',
      'i should',
      'remember to',
      'have to',
      'must',
      'todo',
      'don\'t forget'
    ];
    for (final p in taskPatterns) {
      scores[NoteType.task] = scores[NoteType.task]! + lower.split(p).length - 1;
    }
    // Imperative verbs at sentence start
    scores[NoteType.task] = scores[NoteType.task]! +
        _countImperativeVerbs(transcript);

    // MEETING signals
    final meetingPatterns = [
      'we discussed',
      'meeting',
      'they said',
      'we agreed',
      'call with',
      'synced'
    ];
    for (final p in meetingPatterns) {
      scores[NoteType.meeting] =
          scores[NoteType.meeting]! + lower.split(p).length - 1;
    }
    // Count capitalized names
    scores[NoteType.meeting] =
        scores[NoteType.meeting]! + _countCapitalizedNames(transcript);

    // STUDY signals
    final studyPatterns = [
      'this means',
      'i learned',
      'the concept',
      'basically',
      'in other words',
      'definition',
      'how it works'
    ];
    for (final p in studyPatterns) {
      scores[NoteType.study] =
          scores[NoteType.study]! + lower.split(p).length - 1;
    }

    // REFLECTION signals
    final reflectionPatterns = [
      'i\'ve been thinking',
      'i feel',
      'i realize',
      'honestly',
      'lately',
      'i wonder'
    ];
    for (final p in reflectionPatterns) {
      scores[NoteType.reflection] =
          scores[NoteType.reflection]! + lower.split(p).length - 1;
    }

    // RESEARCH signals
    final researchPatterns = [
      'i read',
      'i heard',
      'according to',
      'study shows',
      'statistic',
      'percent',
      'competitor',
      'the article'
    ];
    for (final p in researchPatterns) {
      scores[NoteType.research] =
          scores[NoteType.research]! + lower.split(p).length - 1;
    }

    // FEEDBACK signals
    final feedbackPatterns = [
      'i think it\'s',
      'works well',
      'doesn\'t work',
      'could be better',
      'the problem with',
      'i\'d improve'
    ];
    for (final p in feedbackPatterns) {
      scores[NoteType.feedback] =
          scores[NoteType.feedback]! + lower.split(p).length - 1;
    }

    // Find type with highest score
    NoteType topType = NoteType.reflection;
    int topScore = scores[NoteType.reflection]!;
    scores.forEach((type, score) {
      if (score > topScore) {
        topScore = score;
        topType = type;
      }
    });

    // If nothing matched, use reflection with low confidence
    if (topScore == 0) {
      return (NoteType.reflection, 0.4);
    }

    // Calculate confidence: topScore / (totalScore + 1), clamped to ~0.5..0.95
    final totalScore = scores.values.fold(0, (a, b) => a + b);
    final rawConfidence = topScore / (totalScore + 1);
    final confidence = (rawConfidence * 0.45 + 0.5).clamp(0.4, 0.95);

    return (topType, confidence);
  }

  /// Count imperative verbs at the start of sentences.
  static int _countImperativeVerbs(String transcript) {
    final imperatives = [
      'call',
      'email',
      'send',
      'finish',
      'buy',
      'fix',
      'schedule',
      'book',
      'write',
      'reach out',
      'connect',
      'review',
      'approve',
      'update'
    ];

    int count = 0;
    final sentences = _splitSentences(transcript);
    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      final lower = trimmed.toLowerCase();
      for (final verb in imperatives) {
        if (lower.startsWith(verb)) {
          count++;
          break;
        }
      }
    }
    return count;
  }

  /// Count capitalized words that look like names (at least 2, not sentence-initial).
  static int _countCapitalizedNames(String transcript) {
    final words = transcript.split(RegExp(r'[\s,;.!?\n]+'));
    final nameWords = <String>{};

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isEmpty) continue;

      final isCapitalized =
          w[0].toUpperCase() == w[0] && w[0] != w[0].toLowerCase();
      if (!isCapitalized) continue;

      // Skip sentence-initial words (very first word or word after . ? !)
      bool isInitial = (i == 0);
      if (i > 0) {
        final prev = words[i - 1];
        if (prev.endsWith('.') || prev.endsWith('?') || prev.endsWith('!')) {
          isInitial = true;
        }
      }

      if (isInitial) continue;

      // Skip common non-name words
      final commonWords = {'The', 'A', 'An', 'And', 'Or', 'But', 'In', 'On', 'At'};
      if (commonWords.contains(w)) continue;

      // Store if length > 2 (reasonable for a name)
      if (w.length > 2) {
        nameWords.add(w);
      }
    }

    return nameWords.length >= 2 ? 1 : 0; // Boost if 2+ distinct names found
  }

  /// Split transcript into sentences (. ? ! and newlines).
  static List<String> _splitSentences(String text) {
    return text
        .split(RegExp(r'[.!?\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
