import 'dart:async';
import 'package:flutter/material.dart';
import 'miko_painter.dart';

class MikoCharacter extends StatefulWidget {
  final MikoState state;
  final double size;

  const MikoCharacter({
    super.key,
    this.state = MikoState.idle,
    this.size = 96,
  });

  @override
  State<MikoCharacter> createState() => _MikoCharacterState();
}

class _MikoCharacterState extends State<MikoCharacter>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _blinkController;
  Timer? _blinkTimer;

  double _anim = 0.0;
  double _blink = 0.0;

  @override
  void initState() {
    super.initState();

    // Main animation controller for state-specific motion (1200ms cycle)
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _animController.addListener(() {
      setState(() {
        _anim = _animController.value;
      });
    });

    // Blink controller (quick 140ms blink)
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 140),
      vsync: this,
    );

    _blinkController.addListener(() {
      setState(() {
        _blink = _blinkController.value;
      });
    });

    // Start idle blink timer (random blink every 3-6 seconds)
    _startBlinkTimer();
  }

  void _startBlinkTimer() {
    _blinkTimer?.cancel();
    final blinkDelay =
        Duration(seconds: 3 + (DateTime.now().millisecond % 3000) ~/ 1000);
    _blinkTimer = Timer(blinkDelay, () {
      if (mounted) {
        _triggerBlink();
        _startBlinkTimer();
      }
    });
  }

  Future<void> _triggerBlink() async {
    await _blinkController.forward();
    await _blinkController.reverse();
  }

  @override
  void didUpdateWidget(MikoCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset/restart animation controller on state change if needed
    if (oldWidget.state != widget.state) {
      // Optionally restart animation on state change
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _blinkController.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomPaint(
      size: Size.square(widget.size),
      painter: MikoPainter(
        state: widget.state,
        blink: _blink,
        anim: _anim,
        isDark: isDark,
      ),
    );
  }
}
