import 'package:flutter/material.dart';
import '../theme/ramble_theme.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../services/app_events.dart';
import '../widgets/note_card.dart';
import '../widgets/miko/miko_character.dart';
import '../widgets/miko/miko_painter.dart';
import 'recording_screen.dart';
import 'note_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Active filter: null = all notes, '' = Inbox, else a projectId.
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ramble;

    return Scaffold(
      backgroundColor: scheme.bg,
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: dataVersion,
          builder: (context, version, _) {
            final allNotes = StorageService.instance.allNotes();
            final allProjects = StorageService.instance.allProjects();
            final inboxNotes = StorageService.instance.inboxNotes();
            final userName = SettingsService.instance.userName;
            // Drop a filter that points at a project that no longer exists.
            if (_filter != null &&
                _filter!.isNotEmpty &&
                !allProjects.any((p) => p.id == _filter)) {
              _filter = null;
            }
            final shownNotes = _filter == null
                ? allNotes
                : allNotes.where((n) => n.projectId == _filter).toList();

            return Stack(
              children: [
                // Main scrollable content
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar (custom Row)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: RambleSpace.s4,
                          vertical: RambleSpace.s3,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left: greeting + prompt
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName.isNotEmpty ? 'hey, ${userName.split(' ').first}.' : 'hey.',
                                  style: RambleType.screenTitle(RambleColors.mikoPurple),
                                ),
                                const SizedBox(height: RambleSpace.s1),
                                Text(
                                  "what's on your mind?",
                                  style: RambleType.label(scheme.inkSoft),
                                ),
                              ],
                            ),
                            // Right: Miko + Settings button
                            Column(
                              children: [
                                MikoCharacter(
                                  state: MikoState.idle,
                                  size: 56,
                                ),
                                const SizedBox(height: RambleSpace.s2),
                                IconButton(
                                  icon: Icon(Icons.settings, color: scheme.ink),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SettingsScreen(),
                                    ),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Empty state or content
                      if (allNotes.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: RambleSpace.s7),
                            child: Column(
                              children: [
                                MikoCharacter(
                                  state: MikoState.idle,
                                  size: 120,
                                ),
                                const SizedBox(height: RambleSpace.s5),
                                Text(
                                  'no notes yet. tap the mic and just talk.',
                                  style: RambleType.body(scheme.inkSoft),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Projects section
                            if (allProjects.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: RambleSpace.s4,
                                  top: RambleSpace.s4,
                                  bottom: RambleSpace.s2,
                                ),
                                child: Text(
                                  'PROJECTS',
                                  style: RambleType.label(scheme.inkSoft),
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: RambleSpace.s4,
                                ),
                                child: Row(
                                  children: [
                                    // Inbox chip
                                    _buildProjectChip(
                                      context: context,
                                      name: 'Inbox',
                                      noteCount: inboxNotes.length,
                                      selected: _filter == '',
                                      onTap: () => setState(
                                          () => _filter = _filter == '' ? null : ''),
                                    ),
                                    // Project chips
                                    ...allProjects.map((project) {
                                      final noteCount =
                                          StorageService.instance
                                              .noteCountForProject(project.id);
                                      return _buildProjectChip(
                                        context: context,
                                        name: project.name,
                                        noteCount: noteCount,
                                        selected: _filter == project.id,
                                        onTap: () => setState(() => _filter =
                                            _filter == project.id
                                                ? null
                                                : project.id),
                                      );
                                    }),
                                  ].expand((w) {
                                    return [w, const SizedBox(width: RambleSpace.s3)];
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: RambleSpace.s4),
                            ],

                            // Recent notes header
                            Padding(
                              padding: const EdgeInsets.only(
                                left: RambleSpace.s4,
                                bottom: RambleSpace.s2,
                              ),
                              child: Text(
                                'RECENT',
                                style: RambleType.label(scheme.inkSoft),
                              ),
                            ),

                            // Notes list
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: RambleSpace.s4,
                              ),
                              child: Column(
                                children: shownNotes
                                    .take(30)
                                    .map((note) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: RambleSpace.s3,
                                        ),
                                        child: NoteCard(
                                          note: note,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  NoteDetailScreen(note: note),
                                            ),
                                          ),
                                        ),
                                      );
                                    })
                                    .toList(),
                              ),
                            ),

                            // Bottom padding for FAB
                            const SizedBox(height: RambleSpace.s8),
                          ],
                        ),
                    ],
                  ),
                ),

                // Record button (bottom center)
                Positioned(
                  bottom: RambleSpace.s5,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RecordingScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: RambleColors.mikoPurple,
                          border: Border.all(
                            color: RambleColors.deepNavy,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              offset: const Offset(4, 4),
                              blurRadius: 0,
                              color: scheme.shadow,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// A project filter chip. Selected = solid ink; tap toggles the home filter.
  Widget _buildProjectChip({
    required BuildContext context,
    required String name,
    required int noteCount,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = context.ramble;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: RambleSpace.s3,
          vertical: RambleSpace.s2,
        ),
        decoration: BoxDecoration(
          color: selected ? scheme.ink : scheme.surface,
          border: Border.all(color: scheme.border, width: RambleGeo.borderWidth),
          borderRadius: BorderRadius.circular(RambleGeo.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: RambleType.body(selected ? scheme.bg : scheme.ink)
                  .copyWith(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: RambleSpace.s1),
            Text(
              '$noteCount ${noteCount == 1 ? 'note' : 'notes'}',
              style: RambleType.caption(
                  selected ? scheme.bg.withValues(alpha: 0.85) : scheme.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
