import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import 'ambient.dart';

/// Small grid of dots used as a texture in corners.
class DotGrid extends StatelessWidget {
  final int rows, cols;
  final double gap;
  final Color color;
  const DotGrid({
    super.key,
    this.rows = 4,
    this.cols = 6,
    this.gap = 11,
    this.color = const Color(0xFFC9C3DE),
  });
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size(cols * gap, rows * gap),
      painter: _DotsPainter(rows, cols, gap, color),
    ),
  );
}

class _DotsPainter extends CustomPainter {
  final int rows, cols;
  final double gap;
  final Color color;
  _DotsPainter(this.rows, this.cols, this.gap, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(Offset(c * gap + 2, r * gap + 2), 1.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

/// Hand-drawn wavy line.
class Squiggle extends StatelessWidget {
  final double width;
  final Color color;
  final double stroke;
  const Squiggle({
    super.key,
    this.width = 64,
    this.color = AppColors.purple,
    this.stroke = 3,
  });
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size(width, 14),
      painter: _SquigglePainter(color, stroke),
    ),
  );
}

class _SquigglePainter extends CustomPainter {
  final Color color;
  final double stroke;
  _SquigglePainter(this.color, this.stroke);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height / 2);
    const waves = 4;
    final step = size.width / waves;
    for (var i = 0; i < waves; i++) {
      final x = i * step;
      path.quadraticBezierTo(
        x + step / 4,
        i.isEven ? 0 : size.height,
        x + step / 2,
        size.height / 2,
      );
      path.quadraticBezierTo(
        x + step * 3 / 4,
        i.isEven ? size.height : 0,
        x + step,
        size.height / 2,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SquigglePainter old) => old.color != color;
}

/// Four-point sparkle star.
class Sparkle extends StatelessWidget {
  final double size;
  final Color color;
  final bool outlined;
  const Sparkle({
    super.key,
    this.size = 16,
    this.color = const Color(0xFFFFD23F),
    this.outlined = true,
  });
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.square(size),
      painter: _SparklePainter(color, outlined),
    ),
  );
}

class _SparklePainter extends CustomPainter {
  final Color color;
  final bool outlined;
  _SparklePainter(this.color, this.outlined);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final path = Path()..moveTo(c.dx, c.dy - r);
    for (final (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)]) {
      final tip = c + Offset(dx * r, dy * r);
      path.quadraticBezierTo(c.dx, c.dy, tip.dx, tip.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    if (outlined) {
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.09
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

/// Heartbeat line drawn under the Health title.
class EcgLine extends StatelessWidget {
  final double width;
  final Color color;
  const EcgLine({super.key, this.width = 76, this.color = AppColors.success});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(size: Size(width, 22), painter: _EcgPainter(color)),
  );
}

class _EcgPainter extends CustomPainter {
  final Color color;
  _EcgPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, m = h * 0.62;
    final path = Path()
      ..moveTo(0, m)
      ..lineTo(w * 0.38, m)
      ..lineTo(w * 0.45, h * 0.15)
      ..lineTo(w * 0.53, h * 0.95)
      ..lineTo(w * 0.6, m)
      ..lineTo(w, m);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_EcgPainter old) => old.color != color;
}

/// Soft blobs, dot grids and rings behind a page.
class PageBackdrop extends StatelessWidget {
  final Widget child;

  /// Colour of the large blob in the top-right corner.
  final Color topBlob;
  final Color bottomBlob;
  const PageBackdrop({
    super.key,
    required this.child,
    this.topBlob = AppColors.lavender,
    this.bottomBlob = AppColors.lavender,
  });
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(right: -90, top: -90, child: _Blob(size: 230, color: topBlob)),
      Positioned(
        left: -70,
        bottom: 110,
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: bottomBlob.withValues(alpha: 0.9),
              width: 18,
            ),
          ),
        ),
      ),
      Positioned(
        right: 22,
        top: MediaQuery.paddingOf(context).top + 20,
        child: const DotGrid(),
      ),
      Positioned.fill(child: child),
    ],
  );
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

/// White rounded square with an arrow, as in the reference designs.
class BackSquare extends StatelessWidget {
  final VoidCallback? onTap;
  const BackSquare({super.key, this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: MaterialLocalizations.of(context).backButtonTooltip,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap ?? () => Navigator.maybePop(context),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.soft,
          ),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
        ),
      ),
    ),
  );
}

/// Large page title with optional back button, subtitle and decoration.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final bool back;
  final Widget? trailing;

  /// Drawn just after the title (e.g. a heartbeat line).
  final Widget? titleAccent;
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.back = false,
    this.trailing,
    this.titleAccent,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        if (back) ...[const BackSquare(), const SizedBox(width: 14)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(child: GlowTitle(title, fontSize: back ? 26 : 32)),
                  if (titleAccent != null) ...[
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: titleAccent,
                    ),
                  ],
                ],
              ),
              if (subtitleWidget != null)
                subtitleWidget!
              else if (subtitle != null)
                Text(subtitle!, style: AppTextStyles.caption),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Coloured rounded square with a section number.
class NumberTile extends StatelessWidget {
  final int number;
  final Color color;
  final double size;
  const NumberTile(
    this.number, {
    super.key,
    required this.color,
    this.size = 34,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Text(
      '$number',
      style: AppTextStyles.heading2.copyWith(
        color: Colors.white,
        fontSize: size * 0.52,
        height: 1,
      ),
    ),
  );
}

/// A pale halo frame around a featured card.
class RingFrame extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  final double width;
  const RingFrame({
    super.key,
    required this.child,
    this.color = AppColors.lavender,
    this.radius = AppRadius.xl,
    this.width = 6,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(width),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius + width),
    ),
    child: child,
  );
}

/// Ink chip with an icon, e.g. "HÔM NAY" on the home hero card.
class InkChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color background;
  final Color foreground;
  const InkChip(
    this.text, {
    super.key,
    this.icon,
    this.background = AppColors.ink,
    this.foreground = Colors.white,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: const Color(0xFFFFD23F)),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.overline.copyWith(
              color: foreground,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Heart sticker with an ink outline, tilted slightly.
class HeartSticker extends StatelessWidget {
  final double size;
  const HeartSticker({super.key, this.size = 26});
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.25,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.favorite_rounded, size: size * 1.2, color: AppColors.ink),
        Icon(
          Icons.favorite_rounded,
          size: size,
          color: const Color(0xFFFF8FA3),
        ),
      ],
    ),
  );
}

/// Horizontal ruler ticks, highlighted in the middle.
class RulerTicks extends StatelessWidget {
  final double height;
  const RulerTicks({super.key, this.height = 26});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _RulerPainter()),
  );
}

class _RulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const gap = 9.0;
    final count = (size.width / gap).floor();
    final mid = count ~/ 2;
    for (var i = 0; i <= count; i++) {
      final x = i * gap + (size.width - count * gap) / 2;
      final major = i % 5 == 0;
      final isMid = i == mid;
      final h = isMid
          ? size.height
          : (major ? size.height * 0.75 : size.height * 0.55);
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        Paint()
          ..color = isMid
              ? AppColors.primaryOrange
              : Colors.white.withValues(alpha: major ? 0.32 : 0.18)
          ..strokeWidth = isMid ? 3 : 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => false;
}

double degToRad(double d) => d * math.pi / 180;

/// Rounded box with a dashed outline, used for "pick something" fields.
class DashedBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color background;
  final double radius;
  final VoidCallback? onTap;
  const DashedBox({
    super.key,
    required this.child,
    this.color = const Color(0xFFC9BDF5),
    this.background = const Color(0xFFF6F3FF),
    this.radius = AppRadius.md,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashPainter(color, radius),
    child: Material(
      color: background,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: child,
      ),
    ),
  );
}

class _DashPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashPainter(this.color, this.radius);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.75),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// White bar pinned to the bottom of a screen with rounded top corners.
class BottomActionBar extends StatelessWidget {
  final Widget child;
  const BottomActionBar({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      16,
      14,
      16,
      14 + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      boxShadow: [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: child,
  );
}

/// Big page title: deep brown lettering with a breathing amber glow,
/// a neon wavy underline and a neon heart that flickers like a sign.
class GlowTitle extends StatefulWidget {
  static const brown = Color(0xFF6B3519);
  static const amber = Color(0xFFFF9F43);
  static const neon = Color(0xFFFF7A3D);

  final String text;
  final double fontSize;
  final bool heart;
  final int maxLines;
  const GlowTitle(
    this.text, {
    super.key,
    this.fontSize = 32,
    this.heart = true,
    this.maxLines = 2,
  });
  @override
  State<GlowTitle> createState() => _GlowTitleState();
}

class _GlowTitleState extends State<GlowTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.of(context)) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop.stop();
      _loop.value = 0.5;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  // Mostly lit, with two quick flickers per loop.
  double _flicker(double t) {
    if ((t > 0.62 && t < 0.65) || (t > 0.69 && t < 0.71)) return 0.25;
    return 1;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _loop,
    builder: (context, _) {
      final t = _loop.value;
      final pulse = 0.5 - 0.5 * math.cos(t * math.pi * 2);
      final size = widget.fontSize;
      final title = Text(
        widget.text,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.heading1.copyWith(
          fontSize: size,
          color: GlowTitle.brown,
          height: 1.1,
          shadows: [
            Shadow(
              color: GlowTitle.amber.withValues(alpha: 0.55 + 0.3 * pulse),
              blurRadius: size * (0.28 + 0.22 * pulse),
            ),
            Shadow(
              color: GlowTitle.amber.withValues(alpha: 0.45),
              blurRadius: 2,
            ),
          ],
        ),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  title,
                  SizedBox(
                    height: size * 0.32,
                    child: CustomPaint(
                      painter: _NeonWavePainter(0.75 + 0.25 * pulse),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.heart)
            Padding(
              padding: EdgeInsets.only(left: size * 0.12, top: size * 0.05),
              child: Opacity(
                opacity: _flicker(t),
                child: Icon(
                  Icons.favorite_border_rounded,
                  size: size * 0.62,
                  color: GlowTitle.neon,
                  shadows: [
                    Shadow(
                      color: GlowTitle.neon.withValues(alpha: 0.9),
                      blurRadius: size * 0.3,
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _NeonWavePainter extends CustomPainter {
  final double glow;
  _NeonWavePainter(this.glow);
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height, w = size.width, m = h * 0.5;
    final waves = math.max(2, (w / 40).round());
    final step = w / waves;
    final path = Path()..moveTo(0, m);
    for (var i = 0; i < waves; i++) {
      final x = i * step;
      path.quadraticBezierTo(x + step / 4, m - h * 0.35, x + step / 2, m);
      path.quadraticBezierTo(x + step * 3 / 4, m + h * 0.35, x + step, m);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = GlowTitle.amber.withValues(alpha: 0.6 * glow)
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.45
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.35),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = GlowTitle.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.5, h * 0.22)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_NeonWavePainter old) => old.glow != glow;
}
