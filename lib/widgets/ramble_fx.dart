import 'package:flutter/material.dart';
import '../theme/ramble_theme.dart';

/// A subtle retro backdrop: a faint dot-grid plus a soft glow bloom at the top.
/// Sits behind a screen's content — never loud, just depth. Scheme-aware.
class RambleBackground extends StatelessWidget {
  final Widget child;
  final Color? glow;

  const RambleBackground({super.key, required this.child, this.glow});

  @override
  Widget build(BuildContext context) {
    final scheme = context.ramble;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _BackdropPainter(
              dot: scheme.ink.withValues(alpha: scheme.isDark ? 0.06 : 0.045),
              glow: (glow ?? RambleColors.mikoPurple)
                  .withValues(alpha: scheme.isDark ? 0.22 : 0.12),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final Color dot;
  final Color glow;
  const _BackdropPainter({required this.dot, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    // Top bloom
    final bloomRect = Rect.fromCircle(
      center: Offset(size.width * 0.5, size.height * 0.08),
      radius: size.width * 0.9,
    );
    final bloom = Paint()
      ..shader = RadialGradient(
        colors: [glow, glow.withValues(alpha: 0)],
      ).createShader(bloomRect);
    canvas.drawRect(Offset.zero & size, bloom);

    // Dot grid
    const gap = 26.0;
    final dotPaint = Paint()..color = dot;
    for (double y = gap; y < size.height; y += gap) {
      for (double x = gap; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.dot != dot || old.glow != glow;
}

/// Text painted with a gradient fill (via ShaderMask). For hero headings.
class RambleGradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;
  final TextAlign? textAlign;

  const RambleGradientText(
    this.text, {
    super.key,
    required this.style,
    this.gradient = RambleGradients.miko,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style.copyWith(color: Colors.white), textAlign: textAlign),
    );
  }
}

/// The hero record control: a gradient mic disc lit from within, with concentric
/// rings pulsing outward. The signature "tap to think" moment.
class GlowRecordButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;
  final IconData icon;

  const GlowRecordButton({
    super.key,
    required this.onTap,
    this.size = 76,
    this.icon = Icons.mic,
  });

  @override
  State<GlowRecordButton> createState() => _GlowRecordButtonState();
}

class _GlowRecordButtonState extends State<GlowRecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.size * 2.4;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: SizedBox(
        width: field,
        height: field,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(
                size: Size(field, field),
                painter: _PulsePainter(_c.value),
              ),
            ),
            AnimatedScale(
              scale: _pressed ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RambleGradients.miko,
                  border: Border.all(color: RambleColors.deepNavy, width: 3),
                  boxShadow: RambleShadows.glow(RambleColors.pixelPink,
                      blur: 28, spread: 2, opacity: 0.6),
                ),
                child: Icon(widget.icon,
                    color: Colors.white, size: widget.size * 0.42),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double t; // 0..1
  const _PulsePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = size.width * 0.21;
    final maxR = size.width * 0.5;
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final r = base + phase * (maxR - base);
      final opacity = (1 - phase) * 0.5;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Color.lerp(RambleColors.pixelPink, RambleColors.mikoPurple,
                phase)!
            .withValues(alpha: opacity);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}

/// Tiny helper: a soft-glowing circular aura behind a child (used on the
/// recording waveform). Pulses gently with [intensity] 0..1.
class GlowAura extends StatelessWidget {
  final Widget child;
  final Color color;
  final double intensity;

  const GlowAura({
    super.key,
    required this.child,
    this.color = RambleColors.mikoPurple,
    this.intensity = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: RambleShadows.glow(color,
            blur: 30 + 30 * intensity.clamp(0, 1), spread: 2, opacity: 0.4),
      ),
      child: child,
    );
  }
}
