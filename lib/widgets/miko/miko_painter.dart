import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/ramble_theme.dart';

enum MikoState { idle, recording, processing, talking, contradiction, excited, sleeping }

class MikoPainter extends CustomPainter {
  final MikoState state;
  final double blink;       // 0..1, 0 = eyes fully open, 1 = eyes closed
  final double anim;        // 0..1 looping animator for state-specific motion
  final bool isDark;

  MikoPainter({
    required this.state,
    required this.blink,
    required this.anim,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / 32;

    // ── Drop shadow ────────────────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = RambleColors.mikoPurple.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    _rect(canvas, shadowPaint, 8, 10, 16, 14, px);

    // ── Bubble body fill ────────────────────────────────────────────────────
    final bodyPaint = Paint()
      ..color = const Color(0xFFF5EDE0)
      ..style = PaintingStyle.fill;
    _rect(canvas, bodyPaint, 8, 8, 16, 16, px);

    // ── Bubble tail (small triangle-like shape pointing down-left) ──────────
    final tailPath = Path();
    tailPath.moveTo((8 + 3) * px, (24) * px);
    tailPath.lineTo((8 + 1) * px, (28) * px);
    tailPath.lineTo((8 + 5) * px, (26) * px);
    tailPath.close();
    canvas.drawPath(tailPath, bodyPaint);

    // ── Bubble pixel border with 3D bevel ──────────────────────────────────
    final borderPaint = Paint()
      ..color = RambleColors.mikoPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * px;

    // Light purple highlight (upper-left)
    final lightBevelPaint = Paint()
      ..color = RambleColors.pixelLavender
      ..style = PaintingStyle.fill;
    _rect(canvas, lightBevelPaint, 8, 8, 14, 1, px); // top edge
    _rect(canvas, lightBevelPaint, 8, 8, 1, 16, px); // left edge

    // Darker purple shadow (lower-right) - create darker shade
    final darkBevelColor = RambleColors.mikoPurple.withOpacity(0.6);
    final darkBevelPaint = Paint()
      ..color = darkBevelColor
      ..style = PaintingStyle.fill;
    _rect(canvas, darkBevelPaint, 22, 8, 2, 16, px); // right edge
    _rect(canvas, darkBevelPaint, 8, 22, 16, 2, px); // bottom edge

    // Main border outline
    canvas.drawRect(
      Rect.fromLTWH(8 * px, 8 * px, 16 * px, 16 * px),
      borderPaint,
    );

    // ── Blush (soft pink ovals on cheeks) ──────────────────────────────────
    final blushPaint = Paint()
      ..color = RambleColors.softBlush.withOpacity(isDark ? 0.6 : 0.4)
      ..style = PaintingStyle.fill;

    // Left cheek
    canvas.drawOval(
      Rect.fromCenter(center: Offset(11 * px, 17 * px), width: 2.5 * px, height: 1.5 * px),
      blushPaint,
    );
    // Right cheek
    canvas.drawOval(
      Rect.fromCenter(center: Offset(21 * px, 17 * px), width: 2.5 * px, height: 1.5 * px),
      blushPaint,
    );

    // ── Eyes ───────────────────────────────────────────────────────────────
    final eyePaint = Paint()
      ..color = RambleColors.deepNavy
      ..style = PaintingStyle.fill;

    if (blink > 0.5 || state == MikoState.sleeping) {
      // Eyes closed: thin horizontal bars
      _rect(canvas, eyePaint, 12, 13, 3, 1, px);  // left eye
      _rect(canvas, eyePaint, 17, 13, 3, 1, px);  // right eye
    } else if (state == MikoState.recording) {
      // Eyes slightly larger (widened)
      _rect(canvas, eyePaint, 12, 12, 3, 3, px);  // left eye
      _rect(canvas, eyePaint, 17, 12, 3, 3, px);  // right eye
    } else if (state == MikoState.processing) {
      // Eyes as small rotating squares (4 steps from anim)
      final step = (anim * 4).toInt() % 4;
      _rect(canvas, eyePaint, 12.0 + (step % 2).toDouble(), 13.0 + (step ~/ 2).toDouble(), 2, 2, px);  // left
      _rect(canvas, eyePaint, 17.0 + (step % 2).toDouble(), 13.0 + (step ~/ 2).toDouble(), 2, 2, px);  // right
    } else if (state == MikoState.contradiction) {
      // One raised eyebrow over narrowed eye
      _rect(canvas, eyePaint, 12, 13, 3, 2, px);  // left eye (narrowed)
      _rect(canvas, eyePaint, 17, 11, 3, 1, px);  // right eyebrow (raised)
    } else {
      // Default: normal eyes (vertical ovals rendered as pixels)
      _rect(canvas, eyePaint, 12, 12, 3, 3, px);  // left eye
      _rect(canvas, eyePaint, 17, 12, 3, 3, px);  // right eye
    }

    // ── Smile ──────────────────────────────────────────────────────────────
    final smilePaint = Paint()
      ..color = RambleColors.deepNavy
      ..style = PaintingStyle.fill;
    _rect(canvas, smilePaint, 14, 18, 4, 1, px);  // smile line
    _rect(canvas, smilePaint, 13, 19, 1, 1, px);  // left curve
    _rect(canvas, smilePaint, 18, 19, 1, 1, px);  // right curve

    // ── Heart (8x8 pixel grid, upper-right) ────────────────────────────────
    final heartPaint = Paint()
      ..color = RambleColors.pixelPink
      ..style = PaintingStyle.fill;

    // Simplified pixel heart at ~(26, 10)
    _rect(canvas, heartPaint, 25, 10, 2, 1, px);  // top-left lobe
    _rect(canvas, heartPaint, 28, 10, 2, 1, px);  // top-right lobe
    _rect(canvas, heartPaint, 24, 11, 5, 1, px);  // middle
    _rect(canvas, heartPaint, 25, 12, 3, 1, px);  // point

    // ── Talking exclamation mark (if state == talking) ─────────────────────
    if (state == MikoState.talking) {
      final exclamationPaint = Paint()
        ..color = RambleColors.pixelPink
        ..style = PaintingStyle.fill;
      _rect(canvas, exclamationPaint, 15, 5, 2, 2, px);   // dot
      _rect(canvas, exclamationPaint, 15, 7, 2, 2, px);   // another dot
    }

    // ── Side waveform bars (animated for recording/processing) ──────────────
    final waveformPaint = Paint()
      ..color = RambleColors.pixelPink
      ..style = PaintingStyle.fill;

    final waveHeight = (state == MikoState.recording || state == MikoState.processing)
        ? 2 + (anim * 3)
        : 2.0;

    // Left bars
    _rect(canvas, waveformPaint, 5, 14 - waveHeight / 2, 1, waveHeight, px);
    _rect(canvas, waveformPaint, 6, 13 - waveHeight / 2, 1, waveHeight + 1, px);

    // Right bars
    _rect(canvas, waveformPaint, 27, 14 - waveHeight / 2, 1, waveHeight, px);
    _rect(canvas, waveformPaint, 28, 13 - waveHeight / 2, 1, waveHeight + 1, px);

    // ── Excited state: small pixel stars around Miko ────────────────────────
    if (state == MikoState.excited) {
      final starPaint = Paint()
        ..color = RambleColors.retroOrange
        ..style = PaintingStyle.fill;

      // 4-point star positions derived from anim
      final positions = [
        (4.0, 12.0 + math.sin(anim * 2) * 2),
        (30.0, 12.0 + math.sin(anim * 2 + 1.57) * 2),
        (16.0, 4.0 + math.sin(anim * 2 + 3.14) * 2),
        (16.0, 26.0 + math.sin(anim * 2 + 4.71) * 2),
      ];

      for (final (x, y) in positions) {
        _rect(canvas, starPaint, x, y, 1, 1, px);
        _rect(canvas, starPaint, x + 1, y, 1, 1, px);
        _rect(canvas, starPaint, x, y + 1, 1, 1, px);
        _rect(canvas, starPaint, x + 1, y + 1, 1, 1, px);
      }
    }
  }

  /// Helper to draw a filled rectangle on a pixel grid.
  void _rect(Canvas c, Paint p, double gx, double gy, double gw, double gh, double px) {
    c.drawRect(
      Rect.fromLTWH(gx * px, gy * px, gw * px, gh * px),
      p,
    );
  }

  @override
  bool shouldRepaint(MikoPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.blink != blink ||
        oldDelegate.anim != anim ||
        oldDelegate.isDark != isDark;
  }
}
