import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ramble_theme.dart';

enum RambleButtonKind { primary, secondary, danger }

class RambleButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final RambleButtonKind kind;
  final IconData? icon;
  final bool expand;

  const RambleButton({
    super.key,
    required this.label,
    this.onTap,
    this.kind = RambleButtonKind.primary,
    this.icon,
    this.expand = false,
  });

  @override
  State<RambleButton> createState() => _RambleButtonState();
}

class _RambleButtonState extends State<RambleButton> {
  bool _pressed = false;

  Color _getBackgroundColor(RambleButtonKind kind) {
    switch (kind) {
      case RambleButtonKind.primary:
        return RambleColors.mikoPurple;
      case RambleButtonKind.secondary:
        return context.ramble.isDark
            ? context.ramble.surface
            : RambleColors.creamBase;
      case RambleButtonKind.danger:
        return RambleColors.warmRed;
    }
  }

  Color _getTextColor(RambleButtonKind kind) {
    switch (kind) {
      case RambleButtonKind.primary:
        return Colors.white;
      case RambleButtonKind.secondary:
        return context.ramble.ink;
      case RambleButtonKind.danger:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.ramble;
    final isDisabled = widget.onTap == null;
    final bgColor = _getBackgroundColor(widget.kind);
    final textColor = _getTextColor(widget.kind);
    final finalBgColor = isDisabled ? bgColor.withOpacity(0.5) : bgColor;
    final finalTextColor = isDisabled ? textColor.withOpacity(0.5) : textColor;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: isDisabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            },
      onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(
          _pressed ? 3 : 0,
          _pressed ? 3 : 0,
          0,
        ),
        width: widget.expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: finalBgColor,
          borderRadius: BorderRadius.circular(RambleGeo.cardRadius),
          border: Border.all(
            color: RambleColors.deepNavy,
            width: RambleGeo.borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              offset: _pressed ? const Offset(0, 0) : const Offset(3, 3),
              blurRadius: 0,
              color: scheme.shadow,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                color: finalTextColor,
                size: 18,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: finalTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
