import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/ramble_theme.dart';
import '../models/note.dart';
import 'ramble_card.dart';
import 'ramble_badge.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.ramble;
    final toneColor = noteToneColor(note.type.tone);
    final timeStr = DateFormat('MMM d · HH:mm').format(note.createdAt);

    return RambleCard(
      onTap: onTap,
      accentStripe: toneColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: badge + spacer + time
          Row(
            children: [
              NoteTypeBadge(note.type),
              const Spacer(),
              Text(
                timeStr,
                style: RambleType.caption(scheme.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            note.title,
            style: RambleType.sectionHeader(scheme.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Key quote if present
          if (note.keyQuote.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note.keyQuote,
              style: RambleType.body(scheme.inkSoft).copyWith(
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Tags (up to 3)
          if (note.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: note.tags.take(3).map((tag) {
                return TagPill(tag, color: toneColor);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
