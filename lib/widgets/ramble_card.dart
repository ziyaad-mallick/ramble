import 'package:flutter/material.dart';
import '../theme/ramble_theme.dart';

class RambleCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? accentStripe;
  final EdgeInsetsGeometry padding;

  const RambleCard({
    super.key,
    required this.child,
    this.onTap,
    this.accentStripe,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<RambleCard> createState() => _RambleCardState();
}

class _RambleCardState extends State<RambleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ramble;
    final isInteractive = widget.onTap != null;

    return GestureDetector(
      onTapDown: isInteractive ? (_) => setState(() => _pressed = true) : null,
      onTapUp: isInteractive
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: isInteractive ? () => setState(() => _pressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(
          _pressed ? 4 : 0,
          _pressed ? 4 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(RambleGeo.cardRadius),
          border: Border.all(
            color: scheme.border,
            width: RambleGeo.borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              offset: _pressed ? const Offset(0, 0) : const Offset(4, 4),
              blurRadius: 0,
              color: scheme.shadow,
            ),
          ],
        ),
        child: Stack(
          children: [
            if (widget.accentStripe != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: widget.accentStripe,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(RambleGeo.cardRadius),
                      bottomLeft: Radius.circular(RambleGeo.cardRadius),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
