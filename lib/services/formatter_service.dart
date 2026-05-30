import '../models/note.dart';
import '../models/project.dart';
import 'intent_service.dart';

class FormatterService {
  /// Build a fully structured Note from a transcript using rule-based logic.
  /// apiKey is accepted for a future LLM path but unused for now (rule-based).
  static Future<Note> buildNote({
    required String transcript,
    required int durationSeconds,
    required List<Project> projects,
    String? apiKey,
  }) async {
    // Generate unique ID
    final id = 'n_${DateTime.now().microsecondsSinceEpoch}';

    // Detect intent and confidence
    final (type, confidence) = IntentService.detect(transcript);

    // Extract title from first sentence
    final sentences = _splitSentences(transcript);
    String title = sentences.isNotEmpty
        ? _sanitizeTitle(sentences.first, maxLength: 60)
        : 'Untitled note';
    if (title.isEmpty) {
      title = 'Untitled note';
    }

    // Extract key quote (longest sentence 5-30 words, else first)
    final keyQuote = _extractKeyQuote(sentences);

    // Build structured fields
    final fields = _buildFields(type, transcript, sentences);

    // Extract tags
    final tags = _extractTags(transcript);

    // Extract items (tasks, questions, decisions, people)
    final items = _extractItems(transcript, sentences);

    // Extract reminders
    final reminders = _extractReminders(sentences);

    // Assign project
    final projectId = _assignProject(transcript, projects);

    // Create and return Note
    return Note(
      id: id,
      title: title,
      type: type,
      projectId: projectId,
      keyQuote: keyQuote,
      fields: fields,
      rawTranscript: transcript,
      tags: tags,
      items: items,
      reminders: reminders,
      confidence: confidence,
      createdAt: DateTime.now(),
      durationSeconds: durationSeconds,
    );
  }

  /// Split transcript into sentences (. ? ! and newlines).
  static List<String> _splitSentences(String text) {
    return text
        .split(RegExp(r'[.!?\n]+') as Pattern)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Sanitize and shorten title: strip filler, capitalize first letter.
  static String _sanitizeTitle(String sentence, {int maxLength = 60}) {
    var title = sentence.trim();

    // Remove common filler phrases from the start
    final fillers = ['so ', 'um ', 'uh ', 'like ', 'you know, ', 'basically, '];
    for (final filler in fillers) {
      if (title.toLowerCase().startsWith(filler)) {
        title = title.substring(filler.length).trim();
      }
    }

    // Capitalize first letter
    if (title.isNotEmpty) {
      title = title[0].toUpperCase() + title.substring(1);
    }

    // Trim to max length
    if (title.length > maxLength) {
      title = title.substring(0, maxLength).trim();
      // If we cut off mid-word, trim back to last space
      final lastSpace = title.lastIndexOf(' ');
      if (lastSpace > 20) {
        title = title.substring(0, lastSpace);
      }
    }

    return title;
  }

  /// Extract key quote: longest sentence 5-30 words, else first sentence.
  static String _extractKeyQuote(List<String> sentences) {
    if (sentences.isEmpty) return '';

    String? bestQuote;
    int bestWordCount = 0;

    for (final sentence in sentences) {
      final wordCount = sentence.split(RegExp(r'\s+')).length;
      if (wordCount >= 5 && wordCount <= 30) {
        if (bestQuote == null || wordCount > bestWordCount) {
          bestQuote = sentence;
          bestWordCount = wordCount;
        }
      }
    }

    return bestQuote ?? sentences.first;
  }

  /// Build structured fields based on type.
  static Map<String, String> _buildFields(
      NoteType type, String transcript, List<String> sentences) {
    final fields = <String, String>{};

    // Initialize all fields for this type as empty
    for (final key in type.fieldKeys) {
      fields[key] = '';
    }

    // Fill fields based on type-specific heuristics
    switch (type) {
      case NoteType.idea:
        fields['Problem'] =
            _extractField(transcript, sentences, ['problem is', 'issue:', 'issue is']);
        fields['Direction'] =
            _extractField(transcript, sentences, ['we could', 'what if', 'idea is']);
        fields['Who it\'s for'] =
            _extractField(transcript, sentences, ['for', 'users', 'customers', 'people']);
        fields['Validate first'] =
            _extractField(transcript, sentences, ['test', 'validate', 'check']);
        fields['Effort'] =
            _extractField(transcript, sentences, ['effort', 'time', 'resources']);
        break;

      case NoteType.task:
        // Action: first imperative sentence
        fields['Action'] = _extractFirstImperative(sentences);
        // Why it matters: sentence with 'because' or 'so that'
        fields['Why it matters'] =
            _extractField(transcript, sentences, ['because', 'so that', 'reason']);
        // Deadline: detect date phrases
        fields['Deadline'] = _extractDatePhrase(transcript);
        // Dependencies: mention of other tasks/people
        fields['Dependencies'] =
            _extractField(transcript, sentences, ['after', 'need', 'depends', 'blocked']);
        // Delegatable: mention of delegation
        fields['Delegatable'] =
            _extractField(transcript, sentences, ['delegate', 'assign', 'give to']);
        break;

      case NoteType.meeting:
        // People: extracted from items
        fields['People'] = _extractPeopleAsString(sentences);
        // Decisions: extracted from items
        fields['Decisions'] = _extractDecisionsAsString(sentences);
        // Actions: extract action items
        fields['Actions'] = _extractField(transcript, sentences,
            ['action item', 'need to', 'i should', 'we\'ll', 'going to']);
        // Open questions: questions from transcript
        fields['Open questions'] = _extractQuestionsAsString(sentences);
        // What changed: changes or agreements
        fields['What changed'] =
            _extractField(transcript, sentences, ['changed', 'agreed', 'decided']);
        break;

      case NoteType.study:
        // Concept: main topic mentioned
        fields['Concept'] = _extractField(
            transcript, sentences, ['concept', 'topic', 'about', 'is about']);
        // Explanation: definition or how-it-works
        fields['Explanation'] =
            _extractField(transcript, sentences, ['means', 'is', 'definition']);
        // Example: look for 'example' or 'like'
        fields['Example'] =
            _extractField(transcript, sentences, ['example', 'like', 'such as']);
        // Still unclear: mention of confusion
        fields['Still unclear'] =
            _extractField(transcript, sentences, ['confused', 'unclear', 'still', 'not sure']);
        // Source: where it came from
        fields['Source'] =
            _extractField(transcript, sentences, ['from', 'source', 'read', 'heard']);
        break;

      case NoteType.reflection:
        // Insight: the realization or key thought
        fields['Insight'] =
            _extractField(transcript, sentences, ['realized', 'realized', 'think', 'feel']);
        // Trigger: what caused the reflection
        fields['Trigger'] =
            _extractField(transcript, sentences, ['because', 'after', 'when', 'seeing']);
        // Tension: conflict or dilemma
        fields['Tension'] =
            _extractField(transcript, sentences, ['tension', 'conflict', 'struggle', 'vs']);
        // Next step: what to do
        fields['Next step'] =
            _extractField(transcript, sentences, ['next', 'should', 'will', 'going to']);
        // Pattern: repeated theme
        fields['Pattern'] =
            _extractField(transcript, sentences, ['pattern', 'always', 'tend', 'usually']);
        break;

      case NoteType.research:
        // Topic: main research subject
        fields['Topic'] = _extractField(
            transcript, sentences, ['topic', 'about', 'research', 'studying']);
        // Key points: main findings
        fields['Key points'] =
            _extractField(transcript, sentences, ['found', 'shows', 'indicates', 'means']);
        // Source: where research came from
        fields['Source'] = _extractField(
            transcript, sentences, ['article', 'paper', 'study', 'source', 'read']);
        // Relevance: why it matters
        fields['Relevance'] =
            _extractField(transcript, sentences, ['relevant', 'matters', 'important']);
        // Follow-up: next research needed
        fields['Follow-up'] =
            _extractField(transcript, sentences, ['follow', 'next', 'more', 'dig deeper']);
        break;

      case NoteType.feedback:
        // Subject: what's being evaluated
        fields['Subject'] =
            _extractField(transcript, sentences, ['product', 'feature', 'design', 'tool']);
        // Working: what works well
        fields['Working'] =
            _extractField(transcript, sentences, ['works well', 'great', 'love', 'excellent']);
        // Broken: what doesn't work
        fields['Broken'] =
            _extractField(transcript, sentences, ['broken', 'doesn\'t work', 'annoying']);
        // Suggestions: improvement ideas
        fields['Suggestions'] =
            _extractField(transcript, sentences, ['suggest', 'could', 'should', 'improve']);
        // Verdict: overall assessment
        fields['Verdict'] = _extractField(
            transcript, sentences, ['think', 'overall', 'verdict', 'rating']);
        break;
    }

    return fields;
  }

  /// Extract a field by finding sentence containing one of the keywords.
  static String _extractField(
      String transcript, List<String> sentences, List<String> keywords) {
    for (final keyword in keywords) {
      for (final sentence in sentences) {
        if (sentence.toLowerCase().contains(keyword)) {
          return sentence;
        }
      }
    }
    return '';
  }

  /// Extract first imperative sentence for task action.
  static String _extractFirstImperative(List<String> sentences) {
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

    for (final sentence in sentences) {
      final lower = sentence.toLowerCase();
      for (final verb in imperatives) {
        if (lower.startsWith(verb)) {
          return sentence;
        }
      }
    }
    return '';
  }

  /// Extract a date phrase (simple heuristic).
  static String _extractDatePhrase(String transcript) {
    final datePatterns = [
      'tomorrow',
      'tonight',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
      'next week',
      'next month',
      'at 5pm',
      'at 6am',
      'on june',
      'in 2 days',
      'in 3 days',
      'this week'
    ];

    final lower = transcript.toLowerCase();
    for (final pattern in datePatterns) {
      if (lower.contains(pattern)) {
        return pattern;
      }
    }
    return '';
  }

  /// Extract people names as a comma-separated string.
  static String _extractPeopleAsString(List<String> sentences) {
    final names = _extractDistinctNames(sentences.join(' '));
    return names.take(8).join(', ');
  }

  /// Extract decisions as a comma-separated string.
  static String _extractDecisionsAsString(List<String> sentences) {
    final decisions = <String>[];
    final decisionKeywords = ['decided', 'we\'ll', 'going with', 'final'];

    for (final sentence in sentences) {
      final lower = sentence.toLowerCase();
      for (final keyword in decisionKeywords) {
        if (lower.contains(keyword)) {
          decisions.add(sentence);
          break;
        }
      }
      if (decisions.length >= 8) break;
    }

    return decisions.join('; ');
  }

  /// Extract questions as a comma-separated string.
  static String _extractQuestionsAsString(List<String> sentences) {
    final questions = sentences.where((s) => s.trim().endsWith('?')).toList();
    return questions.take(8).join('; ');
  }

  /// Extract distinct capitalized names (not sentence-initial).
  static Set<String> _extractDistinctNames(String text) {
    final words = text.split(RegExp(r'[\s,;.!?\n]+'));
    final names = <String>{};
    final commonWords = {'The', 'A', 'An', 'And', 'Or', 'But', 'In', 'On', 'At'};

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isEmpty) continue;

      final isCapitalized =
          w[0].toUpperCase() == w[0] && w[0] != w[0].toLowerCase();
      if (!isCapitalized) continue;

      // Skip sentence-initial
      bool isInitial = (i == 0);
      if (i > 0 && RegExp(r'[.!?]$').hasMatch(words[i - 1])) {
        isInitial = true;
      }
      if (isInitial) continue;

      if (commonWords.contains(w) || w.length <= 2) continue;

      names.add(w);
    }

    return names;
  }

  /// Extract tags: significant words (length > 4) by frequency, excluding stopwords.
  static List<String> _extractTags(String transcript) {
    final stopwords = {
      'the',
      'and',
      'or',
      'but',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'is',
      'are',
      'was',
      'were',
      'be',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'will',
      'would',
      'could',
      'should',
      'may',
      'might',
      'can',
      'a',
      'an',
      'that',
      'this',
      'it',
      'its',
      'i',
      'you',
      'he',
      'she',
      'we',
      'they',
      'what',
      'which',
      'who',
      'when',
      'where',
      'why',
      'how',
    };

    final words = transcript.toLowerCase().split(RegExp(r'[^a-z0-9]+'));
    final frequency = <String, int>{};

    for (final word in words) {
      if (word.length > 4 && !stopwords.contains(word)) {
        frequency[word] = (frequency[word] ?? 0) + 1;
      }
    }

    // Sort by frequency, take top 6
    final sorted = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(6).map((e) => e.key).toList();
  }

  /// Extract items: tasks, questions, decisions, people.
  static List<ExtractedItem> _extractItems(String transcript, List<String> sentences) {
    final items = <ExtractedItem>[];
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

    // Extract tasks
    for (final sentence in sentences) {
      final lower = sentence.toLowerCase();
      bool isTask = false;

      // Check for imperative verbs
      for (final verb in imperatives) {
        if (lower.startsWith(verb)) {
          isTask = true;
          break;
        }
      }

      // Check for task keywords
      if (lower.contains('need to') ||
          lower.contains('should') ||
          lower.contains('have to')) {
        isTask = true;
      }

      if (isTask && items.where((i) => i.kind == 'task').length < 8) {
        items.add(ExtractedItem(kind: 'task', text: sentence));
      }
    }

    // Extract questions
    for (final sentence in sentences) {
      if (sentence.trim().endsWith('?') &&
          items.where((i) => i.kind == 'question').length < 8) {
        items.add(ExtractedItem(kind: 'question', text: sentence));
      }
    }

    // Extract decisions
    final decisionKeywords = ['decided', 'we\'ll', 'going with', 'final'];
    for (final sentence in sentences) {
      final lower = sentence.toLowerCase();
      bool isDecision = false;

      for (final keyword in decisionKeywords) {
        if (lower.contains(keyword)) {
          isDecision = true;
          break;
        }
      }

      if (isDecision &&
          items.where((i) => i.kind == 'decision').length < 8) {
        items.add(ExtractedItem(kind: 'decision', text: sentence));
      }
    }

    // Extract people
    final names = _extractDistinctNames(transcript);
    for (final name in names.take(8)) {
      items.add(ExtractedItem(kind: 'person', text: name));
    }

    return items;
  }

  /// Extract reminders from simple date/time expressions.
  static List<Reminder> _extractReminders(List<String> sentences) {
    final reminders = <Reminder>[];
    final datePatterns = {
      'tomorrow': 1,
      'tonight': 0,
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 0,
      'next week': 7,
      'in 2 days': 2,
      'in 3 days': 3,
    };

    for (final sentence in sentences) {
      final lower = sentence.toLowerCase();

      for (final e in datePatterns.entries) {
        final pattern = e.key;
        final daysOffset = e.value;
        if (lower.contains(pattern)) {
          final dt = DateTime.now().add(Duration(days: daysOffset));
          reminders.add(Reminder(text: sentence, dateTime: dt));
          break;
        }
      }

      if (reminders.length >= 8) break;
    }

    return reminders;
  }

  /// Assign project by matching transcript against project names.
  static String _assignProject(String transcript, List<Project> projects) {
    if (projects.isEmpty) return '';

    final lower = transcript.toLowerCase();
    String? bestProject;
    int bestMatchLength = 0;

    for (final project in projects) {
      final projectNameLower = project.name.toLowerCase();

      if (lower.contains(projectNameLower)) {
        if (projectNameLower.length > bestMatchLength) {
          bestProject = project.id;
          bestMatchLength = projectNameLower.length;
        }
      } else {
        // Try matching individual words from project name
        final projectWords = project.name.split(RegExp(r'\s+'));
        for (final word in projectWords) {
          if (word.length > 3) {
            final wordLower = word.toLowerCase();
            if (lower.contains(wordLower) && wordLower.length > bestMatchLength) {
              bestProject = project.id;
              bestMatchLength = wordLower.length;
            }
          }
        }
      }
    }

    return bestProject ?? '';
  }
}
