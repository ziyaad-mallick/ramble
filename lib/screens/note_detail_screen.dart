import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/miko_response.dart';
import '../models/note.dart';
import '../services/app_events.dart';
import '../services/storage_service.dart';
import '../theme/ramble_theme.dart';
import '../widgets/miko_response_card.dart';
import '../widgets/ramble_badge.dart';
import '../widgets/ramble_card.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note note;
  final MikoResponse? mikoResponse;

  const NoteDetailScreen({
    super.key,
    required this.note,
    this.mikoResponse,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  bool _showMiko = true;

  Future<void> _deleteNote() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await StorageService.instance.deleteNote(widget.note.id);
      bumpData();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _editTitle() async {
    final controller = TextEditingController(text: widget.note.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && mounted) {
      widget.note.title = newTitle;
      await StorageService.instance.saveNote(widget.note);
      bumpData();
      setState(() {});
    }
  }

  void _toggleTaskDone(ExtractedItem item) async {
    item.done = !item.done;
    await StorageService.instance.saveNote(widget.note);
    bumpData();
    setState(() {});
  }

  String _markdown() {
    final lines = <String>[];

    lines.add('# ${widget.note.title}');

    if (widget.note.keyQuote.isNotEmpty) {
      lines.add('> ${widget.note.keyQuote}');
    }

    for (final key in widget.note.type.fieldKeys) {
      final value = widget.note.fields[key];
      if (value != null && value.isNotEmpty) {
        lines.add('**$key**: $value');
      }
    }

    for (final task in widget.note.tasks) {
      final checkbox = task.done ? '[x]' : '[ ]';
      lines.add('- $checkbox ${task.text}');
    }

    if (widget.note.tags.isNotEmpty) {
      lines.add(widget.note.tags.map((t) => '#$t').join(' '));
    }

    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.ramble;

    return Scaffold(
      backgroundColor: scheme.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(RambleSpace.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar: back, spacer, share, delete
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  onPressed: () {
                    Share.share(_markdown());
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: RambleColors.warmRed,
                  onPressed: _deleteNote,
                ),
              ],
            ),
            const SizedBox(height: RambleSpace.s4),

            // Header: badge + spacer + project name + date
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NoteTypeBadge(widget.note.type),
                const Spacer(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${StorageService.instance.projectById(widget.note.projectId)?.name ?? 'Inbox'} · ${DateFormat('MMM d · HH:mm').format(widget.note.createdAt)}',
                        style: RambleType.caption(scheme.inkSoft),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: RambleSpace.s4),

            // Title (tappable)
            GestureDetector(
              onTap: _editTitle,
              child: Text(
                widget.note.title,
                style: RambleType.sectionHeader(scheme.ink).copyWith(fontSize: 22),
              ),
            ),
            const SizedBox(height: RambleSpace.s4),

            // Miko response (if present)
            if (widget.mikoResponse != null &&
                !widget.mikoResponse!.isSilent &&
                _showMiko)
              Column(
                children: [
                  MikoResponseCard(
                    response: widget.mikoResponse!,
                    onDismiss: () => setState(() => _showMiko = false),
                    onRelated: null,
                  ),
                  const SizedBox(height: RambleSpace.s4),
                ],
              ),

            // Key quote (if non-empty)
            if (widget.note.keyQuote.isNotEmpty)
              Column(
                children: [
                  RambleCard(
                    accentStripe: noteToneColor(widget.note.type.tone),
                    child: Text(
                      widget.note.keyQuote,
                      style: RambleType.body(scheme.ink)
                          .copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: RambleSpace.s4),
                ],
              ),

            // Structured fields
            if (_hasStructuredFields())
              Column(
                children: [
                  RambleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final key in widget.note.type.fieldKeys)
                          if (widget.note.fields[key]?.isNotEmpty == true)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  key.toUpperCase(),
                                  style: RambleType.label(scheme.inkSoft),
                                ),
                                const SizedBox(height: RambleSpace.s1),
                                Text(
                                  widget.note.fields[key]!,
                                  style: RambleType.body(scheme.ink),
                                ),
                                Builder(builder: (_) {
                                  final idx = widget.note.type.fieldKeys.indexOf(key);
                                  final nextIdx = idx + 1;
                                  final nextHasValue = nextIdx < widget.note.type.fieldKeys.length &&
                                      widget.note.fields[widget.note.type.fieldKeys[nextIdx]]?.isNotEmpty == true;
                                  return (key != widget.note.type.fieldKeys.last && nextHasValue)
                                      ? const SizedBox(height: RambleSpace.s3)
                                      : const SizedBox.shrink();
                                }),
                              ],
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: RambleSpace.s4),
                ],
              ),

            // Tasks section
            if (widget.note.tasks.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TASKS',
                    style: RambleType.label(scheme.inkSoft),
                  ),
                  const SizedBox(height: RambleSpace.s2),
                  Column(
                    children: [
                      for (final task in widget.note.tasks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: RambleSpace.s2),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _toggleTaskDone(task),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: scheme.border,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                    color: task.done
                                        ? noteToneColor(widget.note.type.tone)
                                        : Colors.transparent,
                                  ),
                                  child: task.done
                                      ? Icon(
                                          Icons.check,
                                          size: 16,
                                          color: scheme.surface,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: RambleSpace.s2),
                              Expanded(
                                child: Text(
                                  task.text,
                                  style: RambleType.body(scheme.ink).copyWith(
                                    decoration: task.done
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: RambleSpace.s4),
                ],
              ),

            // Questions section
            if (widget.note.questions.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QUESTIONS',
                    style: RambleType.label(scheme.inkSoft),
                  ),
                  const SizedBox(height: RambleSpace.s2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final q in widget.note.questions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: RambleSpace.s2),
                          child: Text(
                            '• ${q.text}',
                            style: RambleType.body(scheme.ink),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: RambleSpace.s4),
                ],
              ),

            // Decisions section
            if (widget.note.decisions.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DECISIONS',
                    style: RambleType.label(scheme.inkSoft),
                  ),
                  const SizedBox(height: RambleSpace.s2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final d in widget.note.decisions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: RambleSpace.s2),
                          child: Text(
                            '✓ ${d.text}',
                            style: RambleType.body(scheme.ink),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: RambleSpace.s4),
                ],
              ),

            // People section
            if (widget.note.people.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PEOPLE',
                    style: RambleType.label(scheme.inkSoft),
                  ),
                  const SizedBox(height: RambleSpace.s2),
                  Wrap(
                    spacing: RambleSpace.s2,
                    runSpacing: RambleSpace.s2,
                    children: [
                      for (final p in widget.note.people)
                        TagPill(
                          p.text,
                          color: RambleColors.softBlush,
                        ),
                    ],
                  ),
                  const SizedBox(height: RambleSpace.s4),
                ],
              ),

            // Tags section
            if (widget.note.tags.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: RambleSpace.s2,
                    runSpacing: RambleSpace.s2,
                    children: [
                      for (final tag in widget.note.tags)
                        TagPill(
                          tag,
                          color: noteToneColor(widget.note.type.tone),
                        ),
                    ],
                  ),
                  const SizedBox(height: RambleSpace.s4),
                ],
              ),

            // Transcript expansion tile
            ExpansionTile(
              title: Text(
                'TRANSCRIPT',
                style: RambleType.label(scheme.inkSoft),
              ),
              initiallyExpanded: false,
              children: [
                Container(
                  padding: const EdgeInsets.all(RambleSpace.s3),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border.all(
                      color: scheme.border,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(RambleGeo.cardRadius),
                  ),
                  child: Text(
                    widget.note.rawTranscript,
                    style: RambleType.transcript(scheme.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RambleSpace.s4),

            // Footer stats
            Text(
              '${widget.note.rawTranscript.split(' ').length} words · ${(widget.note.confidence * 100).round()}% confidence · ${widget.note.durationSeconds}s',
              style: RambleType.caption(scheme.inkSoft),
            ),
            const SizedBox(height: RambleSpace.s4),
          ],
        ),
      ),
    );
  }

  bool _hasStructuredFields() {
    return widget.note.type.fieldKeys
        .any((key) => widget.note.fields[key]?.isNotEmpty == true);
  }
}
