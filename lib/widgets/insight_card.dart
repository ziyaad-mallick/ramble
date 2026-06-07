import 'package:flutter/material.dart';
import '../models/note.dart';
import '../theme/ramble_theme.dart';

class InsightCard extends StatelessWidget {
  final Insight insight;

  const InsightCard({super.key, required this.insight});

  /// Maps insight kind to (accent color, icon, label).
  /// Returns (Color, IconData, String) tuple.
  ({Color color, IconData icon, String label}) _getKindStyle() {
    switch (insight.kind) {
      case 'support':
        return (color: RambleColors.bit8Green, icon: Icons.check_rounded, label: 'SUPPORTS');
      case 'correction':
        return (color: RambleColors.retroOrange, icon: Icons.edit_rounded, label: 'CORRECTION');
      case 'contradiction':
        return (color: RambleColors.warmRed, icon: Icons.bolt_rounded, label: 'CONTRADICTION');
      case 'question':
        return (color: RambleColors.pixelSky, icon: Icons.help_outline_rounded, label: 'WORTH ASKING');
      case 'stat':
        return (color: RambleColors.mikoPurple, icon: Icons.insights_rounded, label: 'STAT');
      default:
        return (color: RambleColors.mikoPurple, icon: Icons.auto_awesome_rounded, label: 'MIKO');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.ramble;
    final style = _getKindStyle();
    final accentColor = style.color;
    final iconData = style.icon;
    final label = style.label;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(RambleGeo.cardRadius),
        border: Border.all(color: accentColor, width: RambleGeo.borderWidth),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.4),
            offset: const Offset(RambleGeo.pixelShadowOffset, RambleGeo.pixelShadowOffset),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(RambleSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading chip
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(RambleGeo.cardRadius / 2),
              border: Border.all(
                color: RambleColors.deepNavy,
                width: RambleGeo.borderWidth,
              ),
            ),
            child: Center(
              child: Icon(
                iconData,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: RambleSpace.s3),
          // Content column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kind label
                Text(
                  label,
                  style: RambleType.label(accentColor),
                ),
                const SizedBox(height: RambleSpace.s1),
                // Insight text
                Text(
                  insight.text,
                  style: RambleType.body(scheme.ink),
                ),
                // Source row (if present)
                if (insight.source.isNotEmpty) ...[
                  const SizedBox(height: RambleSpace.s2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.link,
                        size: 12,
                        color: scheme.inkSoft,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          insight.source,
                          style: RambleType.caption(scheme.inkSoft),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
