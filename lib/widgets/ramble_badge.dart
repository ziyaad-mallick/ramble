import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ramble_theme.dart';
import '../models/note.dart';

class NoteTypeBadge extends StatelessWidget {
  final NoteType type;

  const NoteTypeBadge(this.type, {super.key});

  @override
  Widget build(BuildContext context) {
    final toneColor = noteToneColor(type.tone);
    final bgColor = toneColor.withOpacity(0.15);
    final borderColor = toneColor.withOpacity(0.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(RambleGeo.badgeRadius),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        type.label.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: toneColor,
        ),
      ),
    );
  }
}

class TagPill extends StatelessWidget {
  final String text;
  final Color color;

  const TagPill(
    this.text, {
    super.key,
    this.color = RambleColors.mikoPurple,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color.withOpacity(0.15);
    final borderColor = color.withOpacity(0.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(RambleGeo.badgeRadius),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        '#$text',
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
