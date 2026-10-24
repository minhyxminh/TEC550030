import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

class AppMotion {
  /// Endless decorative motion (bubbles, glow). Tests switch it off.
  static bool ambient = true;

  static bool of(BuildContext context) =>
      ambient && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
}

/// Mixin for a looping controller that respects [AppMotion].
mixin _Looping<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  Duration get period;
  late final AnimationController loop = AnimationController(
    vsync: this,
    duration: period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.of(context)) {
      if (!loop.isAnimating) loop.repeat();
    } else {
      loop.stop();
    }
  }

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }
}

class _Bubble {
  final double x, y, r, speed, offset, strength;
  const _Bubble(this.x, this.y, this.r, this.speed, this.offset, this.strength);
}

/// Soft white bubbles that drift and fade in and out behind card content,
/// with a few small accent shapes (purple squares, ink dots).
class AmbientBubbles extends StatefulWidget {
  final Color color;
  final bool accents;
  final int seed;
  final double intensity;
  const AmbientBubbles({
    super.key,
    this.color = Colors.white,
    this.accents = true,
    this.seed = 1,
    this.intensity = 1,
  });
  @override
  State<AmbientBubbles> createState() => _AmbientBubblesState();
}

class _AmbientBubblesState extends State<AmbientBubbles>
    with SingleTickerProviderStateMixin, _Looping {
  @override
  Duration get period => const Duration(seconds: 7);
  late List<_Bubble> _bubbles = _make(widget.seed);

  static List<_Bubble> _make(int seed) {
    final r = math.Random(seed);
    return [
      // One large bubble anchors the top-right corner, like a sun.
      _Bubble(0.88, 0.05, 0.42, 1, r.nextDouble() * 6, 0.9),
      for (var i = 0; i < 5; i++)
        _Bubble(
          r.nextDouble(),
          r.nextDouble(),
          0.04 + r.nextDouble() * 0.1,
          1 + r.nextInt(2).toDouble(),
          r.nextDouble() * math.pi * 2,
          0.5 + r.nextDouble() * 0.5,
        ),
    ];
  }

  @override
  void didUpdateWidget(covariant AmbientBubbles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed) _bubbles = _make(widget.seed);
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _BubblePainter(
          loop,
          _bubbles,
          widget.color,
          widget.accents,
          widget.intensity,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class _BubblePainter extends CustomPainter {
  final Animation<double> t;
  final List<_Bubble> bubbles;
  final Color color;
  final bool accents;
  final double intensity;
  _BubblePainter(this.t, this.bubbles, this.color, this.accents, this.intensity)
    : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t.value * math.pi * 2;
    final base = math.min(size.width, size.height * 1.6);
    for (final b in bubbles) {
      final p = phase * b.speed + b.offset;
      // Fade between barely visible and clearly visible.
      final pulse = 0.5 + 0.5 * math.sin(p);
      final alpha = (0.06 + 0.22 * pulse) * b.strength * intensity;
      final center = Offset(
        size.width * b.x + math.cos(p * 0.5) * base * 0.03,
        size.height * b.y + math.sin(p * 0.5) * base * 0.04,
      );
      final radius = base * b.r * (0.94 + 0.06 * pulse);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.55),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    if (!accents) return;
    void square(double x, double y, double s, Color c, double o) {
      canvas.save();
      canvas.translate(
        size.width * x,
        size.height * y + math.sin(phase + o) * 4,
      );
      canvas.rotate(0.4 + math.sin(phase + o) * 0.35);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: s, height: s),
          Radius.circular(s * 0.28),
        ),
        Paint()..color = c,
      );
      canvas.restore();
    }

    // Accents stay on the right so they never sit on top of text.
    square(0.66, 0.1, 11, AppColors.purple.withValues(alpha: 0.85), 0);
    square(0.95, 0.66, 8, AppColors.purple.withValues(alpha: 0.7), 2);
    final twinkle = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(phase * 2 + 1));
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.16 + math.cos(phase) * 3),
      3.5,
      Paint()..color = AppColors.ink.withValues(alpha: 0.75 * twinkle),
    );
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.4 + math.sin(phase) * 3),
      4.5,
      Paint()..color = Colors.white.withValues(alpha: 0.9 * twinkle),
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.color != color || old.bubbles != bubbles;
}

/// A featured card: coloured surface, drifting bubbles and a glow that
/// breathes around its edge so it stands out from the plain cards.
class HighlightCard extends StatefulWidget {
  final Widget child;
  final Color color;
  final Gradient? gradient;
  final Color glow;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool accents;
  final int seed;
  final Color bubbleColor;
  final double bubbleIntensity;
  const HighlightCard({
    super.key,
    required this.child,
    this.color = AppColors.primaryOrange,
    this.gradient,
    Color? glow,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadius.xl,
    this.onTap,
    this.accents = false,
    this.seed = 1,
    this.bubbleColor = Colors.white,
    this.bubbleIntensity = 1,
  }) : glow = glow ?? color;
  @override
  State<HighlightCard> createState() => _HighlightCardState();
}

class _HighlightCardState extends State<HighlightCard>
    with SingleTickerProviderStateMixin, _Looping {
  @override
  Duration get period => const Duration(milliseconds: 3600);

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(widget.radius);
    return AnimatedBuilder(
      animation: loop,
      builder: (context, child) {
        final pulse = 0.5 + 0.5 * math.sin(loop.value * math.pi * 2);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            boxShadow: [
              BoxShadow(
                color: widget.glow.withValues(alpha: 0.20 + 0.18 * pulse),
                blurRadius: 18 + 14 * pulse,
                spreadRadius: 1 + 2 * pulse,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: shape,
        child: Material(
          color: widget.gradient == null ? widget.color : null,
          child: Ink(
            decoration: BoxDecoration(gradient: widget.gradient),
            child: InkWell(
              onTap: widget.onTap,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AmbientBubbles(
                      accents: widget.accents,
                      seed: widget.seed,
                      color: widget.bubbleColor,
                      intensity: widget.bubbleIntensity,
                    ),
                  ),
                  Padding(padding: widget.padding, child: widget.child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
