import 'package:flutter/material.dart';
import 'miko_painter.dart'; // kept for the MikoState enum (call-site API compatibility)

/// Miko — now rendered from the real pixel-art asset (assets/miko.png) instead
/// of the code-drawn placeholder. [state] is accepted for API compatibility with
/// existing call sites but no longer changes the face; [size] controls dimensions.
class MikoCharacter extends StatelessWidget {
  final MikoState state;
  final double size;

  const MikoCharacter({
    super.key,
    this.state = MikoState.idle,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/miko.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none, // keep the pixels crisp when scaled
    );
  }
}
