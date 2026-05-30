import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../../theme/ramble_theme.dart';

/// Miko Waveform: A signature visual of the Ramble app.
///
/// Renders a 4x4px dot that travels left→right across a widget, following a
/// smooth sine wave path. The amplitude scales with audio volume (`level` 0..1).
/// A gradient trail behind the dot transitions from Miko Purple → Pixel Pink.
/// A faint dashed center line anchors the animation.
///
/// When [looping] is true, renders a gentle fixed-amplitude loop (used during
/// processing states), pulsing the color between purple and pink. Otherwise,
/// the amplitude smoothly interpolates toward [level].
class MikoWaveform extends StatefulWidget {
  /// Current audio amplitude (0..1). Ignored when [looping] is true.
  final double level;

  /// Widget height in logical pixels. Sine amplitude is a fraction of this.
  final double height;

  /// If true, ignores [level] and renders a gentle looping animation with
  /// color pulsing purple↔pink. Used during processing/loading states.
  final bool looping;

  const MikoWaveform({
    super.key,
    required this.level,
    this.height = 140,
    this.looping = false,
  });

  @override
  State<MikoWaveform> createState() => _MikoWaveformState();
}

class _MikoWaveformState extends State<MikoWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Offset> _trail;
  double _displayedAmplitude = 0.0;

  // Max trail positions to maintain (~20 for comet effect).
  static const int _maxTrailLength = 20;

  @override
  void initState() {
    super.initState();
    _trail = [];
    _displayedAmplitude = widget.looping ? 0.3 : widget.level;

    // 4000ms cycle for a gentle, smooth animation.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void didUpdateWidget(MikoWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If looping state changes, reset displayed amplitude.
    if (oldWidget.looping != widget.looping) {
      _displayedAmplitude = widget.looping ? 0.3 : widget.level;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Computes the dot position for a given horizontal phase (0..1).
  /// Returns an [Offset] in the widget's local coordinate system.
  Offset _computeDotPosition(double phase, double width, double height) {
    final x = phase * width;

    // Sine wave: amplitude varies with displayedAmplitude, frequency is fixed.
    // Use phase * 2π for a single complete oscillation across the width.
    // Frequency factor: 2 cycles across the width for visual interest.
    const frequencyFactor = 2.0;
    final sinePhase = phase * 2.0 * math.pi * frequencyFactor;
    final sineValue = math.sin(sinePhase);

    // Amplitude scales with displayed amplitude and half the height.
    final amplitude = _displayedAmplitude * height * 0.25;
    final centerY = height / 2.0;
    final y = centerY + (sineValue * amplitude);

    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = widget.height;

        // On each frame, update the displayed amplitude and trail.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              // Smooth interpolation of amplitude toward target.
              final targetAmplitude =
                  widget.looping ? 0.3 : widget.level.clamp(0.0, 1.0);
              const lerpFactor = 0.1; // Smooth but responsive.
              _displayedAmplitude =
                  lerpDouble(_displayedAmplitude, targetAmplitude, lerpFactor) ??
                      targetAmplitude;

              // Compute the current dot position based on controller value.
              final phase = _controller.value;
              final dotPos = _computeDotPosition(phase, width, height);

              // Add to trail and maintain max length.
              _trail.add(dotPos);
              if (_trail.length > _maxTrailLength) {
                _trail.removeAt(0);
              }
            });
          }
        });

        return CustomPaint(
          painter: _WavePainter(
            trail: _trail,
            displayedAmplitude: _displayedAmplitude,
            phase: _controller.value,
            looping: widget.looping,
            width: width,
            height: height,
          ),
          size: Size(width, height),
        );
      },
    );
  }
}

/// Paints the waveform: dashed center line, comet trail, and head dot.
class _WavePainter extends CustomPainter {
  final List<Offset> trail;
  final double displayedAmplitude;
  final double phase;
  final bool looping;
  final double width;
  final double height;

  _WavePainter({
    required this.trail,
    required this.displayedAmplitude,
    required this.phase,
    required this.looping,
    required this.width,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw dashed center line (Pixel Lavender @ 30% opacity).
    _drawDashedCenterLine(canvas, size);

    // 2. Draw comet trail (decreasing opacity).
    _drawTrail(canvas);

    // 3. Draw head dot (4x4 rect, colored by horizontal gradient).
    _drawHeadDot(canvas);
  }

  /// Draws a thin dashed horizontal line at the vertical center.
  void _drawDashedCenterLine(Canvas canvas, Size size) {
    const centerLineColor = RambleColors.pixelLavender;
    final paint = Paint()
      ..color = centerLineColor.withOpacity(0.3)
      ..strokeWidth = 1.0;

    const dashWidth = 4.0;
    const dashGap = 4.0;
    const totalDash = dashWidth + dashGap;

    final centerY = height / 2.0;
    var x = 0.0;
    while (x < width) {
      canvas.drawLine(
        Offset(x, centerY),
        Offset((x + dashWidth).clamp(0, width), centerY),
        paint,
      );
      x += totalDash;
    }
  }

  /// Draws the comet trail: previous dot positions with fading opacity.
  void _drawTrail(Canvas canvas) {
    if (trail.isEmpty) return;

    for (int i = 0; i < trail.length; i++) {
      // Opacity fades from 20% (oldest) to near 0% (newest).
      final progress = i / trail.length;
      final opacity = 0.2 * (1.0 - progress); // 20% → 0%

      // Interpolate color based on the position's x coordinate.
      final trailPos = trail[i];
      final colorT = (trailPos.dx / width).clamp(0.0, 1.0);
      final trailColor = Color.lerp(
        RambleColors.mikoPurple,
        RambleColors.pixelPink,
        colorT,
      )!;

      final paint = Paint()
        ..color = trailColor.withOpacity(opacity);

      const dotSize = 4.0;
      canvas.drawRect(
        Rect.fromLTWH(
          trailPos.dx - dotSize / 2.0,
          trailPos.dy - dotSize / 2.0,
          dotSize,
          dotSize,
        ),
        paint,
      );
    }
  }

  /// Draws the head dot: a 4x4 rect colored by horizontal position gradient.
  void _drawHeadDot(Canvas canvas) {
    // Current dot position based on phase.
    final dotPos = _computeDotPosition(phase);
    final colorT = (dotPos.dx / width).clamp(0.0, 1.0);

    Color headColor;
    if (looping) {
      // Pulse the color between purple and pink based on phase.
      final colorPhase = phase * 2.0 * math.pi;
      final colorLerpT = (math.sin(colorPhase) + 1.0) / 2.0; // 0..1
      headColor = Color.lerp(
        RambleColors.mikoPurple,
        RambleColors.pixelPink,
        colorLerpT,
      )!;
    } else {
      // Color based on horizontal position.
      headColor = Color.lerp(
        RambleColors.mikoPurple,
        RambleColors.pixelPink,
        colorT,
      )!;
    }

    final paint = Paint()..color = headColor;

    const dotSize = 4.0;
    canvas.drawRect(
      Rect.fromLTWH(
        dotPos.dx - dotSize / 2.0,
        dotPos.dy - dotSize / 2.0,
        dotSize,
        dotSize,
      ),
      paint,
    );
  }

  /// Computes the dot position for a given phase (0..1).
  Offset _computeDotPosition(double phaseValue) {
    final x = phaseValue * width;

    // Sine wave: amplitude varies with displayedAmplitude, frequency is fixed.
    const frequencyFactor = 2.0;
    final sinePhase = phaseValue * 2.0 * math.pi * frequencyFactor;
    final sineValue = math.sin(sinePhase);

    final amplitude = displayedAmplitude * height * 0.25;
    final centerY = height / 2.0;
    final y = centerY + (sineValue * amplitude);

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => true;
}
