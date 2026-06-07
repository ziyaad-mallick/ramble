import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/note.dart';
import '../services/app_events.dart';
import '../services/document_service.dart';
import '../services/local_llm_service.dart';
import '../services/storage_service.dart';
import '../services/thinking_service.dart';
import '../theme/ramble_theme.dart';
import '../widgets/insight_card.dart';
import '../widgets/ramble_badge.dart';
import '../widgets/ramble_card.dart';

/// The thinking document — Miko's structured read of a ramble: summary, the arc
/// of the thought, her interventions, and an on-demand "ask Miko" deep dive.
class NoteDetailScreen extends StatefulWidget {
  final Note note;

  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final _askController = TextEditingController();
  bool _asking = false;

  Note get note => widget.note;

  @override
  void dispose() {
    _askController.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _deleteNote() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await StorageService.instance.deleteNote(note.id);
      bumpData();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _editTitle() async {
    final controller = TextEditingController(text: note.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (newTitle != null && newTitle.trim().isNotEmpty && mounted) {
      note.title = newTitle.trim();
      await StorageService.instance.saveNote(note);
      bumpData();
      setState(() {});
    }
  }

  Future<void> _toggleTask(ExtractedItem item) async {
    item.done = !item.done;
    await StorageService.instance.saveNote(note);
    bumpData();
    setState(() {});
  }

  Future<void> _askMiko() async {
    final query = _askController.text.trim();
    if (query.isEmpty || _asking) return;
    FocusScope.of(context).unfocus();
    setState(() => _asking = true);
    try {
      final insight = await ThinkingService.deepDive(note: note, query: query);
      note.insights.add(insight);
      await StorageService.instance.saveNote(note);
      bumpData();
      _askController.clear();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Download Miko\'s brain in settings to ask.')),
        );
      }
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = context.ramble;
    final projectName =
        StorageService.instance.projectById(note.projectId)?.name ?? 'Inbox';

    return Scaffold(
      backgroundColor: scheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(RambleSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(scheme),
              const SizedBox(height: RambleSpace.s4),
              _metaRow(scheme, projectName),
              const SizedBox(height: RambleSpace.s3),
              GestureDetector(
                onTap: _editTitle,
                child: Text(
                  note.title,
                  style: RambleType.sectionHeader(scheme.ink).copyWith(fontSize: 24),
                ),
              ),
              const SizedBox(height: RambleSpace.s5),

              if (note.summary.isNotEmpty) ...[
                _sectionLabel('SUMMARY', scheme),
                const SizedBox(height: RambleSpace.s2),
                RambleCard(
                  accentStripe: noteToneColor(note.type.tone),
                  child: Text(note.summary, style: RambleType.body(scheme.ink)),
                ),
                const SizedBox(height: RambleSpace.s5),
              ],

              if (note.arc.isNotEmpty) ...[
                _sectionLabel('THE ARC OF YOUR THINKING', scheme),
                const SizedBox(height: RambleSpace.s3),
                _arcThread(scheme),
                const SizedBox(height: RambleSpace.s5),
              ],

              if (note.insights.isNotEmpty) ...[
                Row(
                  children: [
                    _sectionLabel('MIKO', scheme),
                    const SizedBox(width: RambleSpace.s2),
                    Text('your thinking partner',
                        style: RambleType.caption(scheme.inkSoft)),
                  ],
                ),
                const SizedBox(height: RambleSpace.s3),
                for (final insight in note.insights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RambleSpace.s3),
                    child: InsightCard(insight: insight),
                  ),
                const SizedBox(height: RambleSpace.s2),
              ],

              _askMikoBox(scheme),
              const SizedBox(height: RambleSpace.s5),

              if (note.tasks.isNotEmpty) ...[
                _sectionLabel('TASKS', scheme),
                const SizedBox(height: RambleSpace.s2),
                for (final task in note.tasks) _taskRow(task, scheme),
                const SizedBox(height: RambleSpace.s5),
              ],

              if (note.questions.isNotEmpty) ...[
                _sectionLabel('OPEN QUESTIONS', scheme),
                const SizedBox(height: RambleSpace.s2),
                for (final q in note.questions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RambleSpace.s2),
                    child: Text('• ${q.text}', style: RambleType.body(scheme.ink)),
                  ),
                const SizedBox(height: RambleSpace.s5),
              ],

              if (note.tags.isNotEmpty) ...[
                Wrap(
                  spacing: RambleSpace.s2,
                  runSpacing: RambleSpace.s2,
                  children: [
                    for (final tag in note.tags)
                      TagPill(tag, color: noteToneColor(note.type.tone)),
                  ],
                ),
                const SizedBox(height: RambleSpace.s5),
              ],

              _exportRow(scheme),
              const SizedBox(height: RambleSpace.s5),

              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: _sectionLabel('TRANSCRIPT', scheme),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(RambleSpace.s3),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      border: Border.all(color: scheme.border, width: 2),
                      borderRadius: BorderRadius.circular(RambleGeo.cardRadius),
                    ),
                    child: Text(note.rawTranscript,
                        style: RambleType.transcript(scheme.ink)),
                  ),
                ],
              ),
              const SizedBox(height: RambleSpace.s3),
              Text(
                '${note.analyzed ? 'analyzed by Miko' : 'offline draft'} · ${note.durationSeconds}s · ${DateFormat('MMM d').format(note.createdAt)}',
                style: RambleType.caption(scheme.inkSoft),
              ),
              const SizedBox(height: RambleSpace.s4),
            ],
          ),
        ),
      ),
    );
  }

  // ── Pieces ─────────────────────────────────────────────────────────────

  Widget _topBar(RambleScheme scheme) => Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            visualDensity: VisualDensity.compact,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: RambleColors.warmRed,
            onPressed: _deleteNote,
            visualDensity: VisualDensity.compact,
          ),
        ],
      );

  Widget _metaRow(RambleScheme scheme, String projectName) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          NoteTypeBadge(note.type),
          if (note.context.isNotEmpty) ...[
            const SizedBox(width: RambleSpace.s2),
            _contextChip(note.context),
          ],
          const Spacer(),
          Flexible(
            child: Text(
              '$projectName · ${DateFormat('MMM d · HH:mm').format(note.createdAt)}',
              style: RambleType.caption(scheme.inkSoft),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      );

  Widget _contextChip(String context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: RambleSpace.s2, vertical: RambleSpace.s1),
        decoration: BoxDecoration(
          color: RambleColors.mikoPurple,
          borderRadius: BorderRadius.circular(RambleGeo.badgeRadius),
        ),
        child:
            Text(context.toLowerCase(), style: RambleType.caption(Colors.white)),
      );

  Widget _sectionLabel(String text, RambleScheme scheme) =>
      Text(text, style: RambleType.label(scheme.inkSoft));

  /// Vertical thread tracing how the thinking moved.
  Widget _arcThread(RambleScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < note.arc.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _arcColor(note.arc[i].kind),
                        border:
                            Border.all(color: RambleColors.deepNavy, width: 2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    if (i != note.arc.length - 1)
                      Expanded(child: Container(width: 2, color: scheme.border)),
                  ],
                ),
                const SizedBox(width: RambleSpace.s3),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: i == note.arc.length - 1 ? 0 : RambleSpace.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_arcLabel(note.arc[i].kind),
                            style: RambleType.caption(_arcColor(note.arc[i].kind))
                                .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: RambleSpace.s1),
                        Text(note.arc[i].text,
                            style: RambleType.body(scheme.ink)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _arcColor(String kind) {
    switch (kind) {
      case 'start':
        return RambleColors.mikoPurple;
      case 'turn':
        return RambleColors.retroOrange;
      case 'landing':
        return RambleColors.bit8Green;
      default:
        return RambleColors.pixelSky;
    }
  }

  String _arcLabel(String kind) {
    switch (kind) {
      case 'start':
        return 'STARTED';
      case 'turn':
        return 'TURNED';
      case 'landing':
        return 'LANDED';
      default:
        return 'THEN';
    }
  }

  Widget _taskRow(ExtractedItem task, RambleScheme scheme) => Padding(
        padding: const EdgeInsets.only(bottom: RambleSpace.s2),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleTask(task),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.border, width: 2),
                  borderRadius: BorderRadius.circular(2),
                  color: task.done
                      ? noteToneColor(note.type.tone)
                      : Colors.transparent,
                ),
                child: task.done
                    ? Icon(Icons.check, size: 16, color: scheme.surface)
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
      );

  /// The deep-dive box — ask Miko to pull stats, fact-check, or find holes.
  Widget _askMikoBox(RambleScheme scheme) {
    final ready = LocalLlmService.instance.isInstalled;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RambleSpace.s4),
      decoration: BoxDecoration(
        color: RambleColors.deepNavy,
        borderRadius: BorderRadius.circular(RambleGeo.cardRadius),
        border: Border.all(color: RambleColors.mikoPurple, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: RambleColors.pixelLavender, size: 16),
              const SizedBox(width: RambleSpace.s2),
              Text('ASK MIKO', style: RambleType.label(Colors.white)),
            ],
          ),
          const SizedBox(height: RambleSpace.s2),
          if (!ready)
            Text(
              'download Miko\'s brain in settings, then ask her to find holes, counter your thinking, or sketch what you\'re missing — all on-device.',
              style: RambleType.caption(RambleColors.pixelLavender),
            )
          else ...[
            Text(
              'e.g. "find holes in this" · "what am I missing?" · "argue the other side"',
              style: RambleType.caption(RambleColors.pixelLavender),
            ),
            const SizedBox(height: RambleSpace.s3),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _askController,
                    enabled: !_asking,
                    style: RambleType.body(Colors.white),
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _askMiko(),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: RambleColors.crtOffBlack,
                      hintText: 'ask Miko to dig deeper…',
                      hintStyle: RambleType.body(RambleColors.gameboyGray),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(RambleGeo.inputRadius),
                        borderSide: const BorderSide(
                            color: RambleColors.mikoPurple, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(RambleGeo.inputRadius),
                        borderSide: const BorderSide(
                            color: RambleColors.mikoPurple, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(RambleGeo.inputRadius),
                        borderSide: const BorderSide(
                            color: RambleColors.pixelPink, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: RambleSpace.s2),
                GestureDetector(
                  onTap: _asking ? null : _askMiko,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: RambleColors.mikoPurple,
                      borderRadius:
                          BorderRadius.circular(RambleGeo.inputRadius),
                    ),
                    child: _asking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _exportRow(RambleScheme scheme) => Row(
        children: [
          Expanded(
            child: _exportButton(
              scheme,
              icon: Icons.description_outlined,
              label: 'MARKDOWN',
              onTap: () => Share.share(DocumentService.toMarkdown(note)),
            ),
          ),
          const SizedBox(width: RambleSpace.s3),
          Expanded(
            child: _exportButton(
              scheme,
              icon: Icons.picture_as_pdf_outlined,
              label: 'PDF',
              onTap: () => DocumentService.sharePdf(note),
            ),
          ),
        ],
      );

  Widget _exportButton(RambleScheme scheme,
          {required IconData icon,
          required String label,
          required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: RambleSpace.s3),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(RambleGeo.cardRadius),
            border: Border.all(color: scheme.border, width: 2),
            boxShadow: [
              BoxShadow(
                  offset: const Offset(3, 3),
                  blurRadius: 0,
                  color: scheme.shadow),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: scheme.ink),
              const SizedBox(width: RambleSpace.s2),
              Text(label, style: RambleType.label(scheme.ink)),
            ],
          ),
        ),
      );
}
