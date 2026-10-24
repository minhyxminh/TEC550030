import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../models/mascot_mood.dart';

const _aspect = 1137 / 1033;
const _tau = math.pi * 2;

/// A looping run of the tiger's own animation frames (assets/mascot/).
/// The frames come straight from the brand animation, so the character is
/// never redrawn; code only picks the frame and adds motion around it.
class _Clip {
  final String name;
  final List<int> frames;
  final double fps;

  /// Whole body visible down to the feet (gets a ground shadow).
  final bool fullBody;
  const _Clip(this.name, this.frames, this.fps, {this.fullBody = false});

  String path(int i) =>
      'assets/mascot/${name}_${i.toString().padLeft(2, '0')}.webp';
  Iterable<String> get paths => frames.toSet().map(path);
}

List<int> _pingPong(int from, int to) => [
  for (var i = from; i <= to; i++) i,
  for (var i = to - 1; i > from; i--) i,
];

// Frame indices refer to the exported files: idle_00 is source frame 16, etc.
final _idleClip = _Clip('idle', _pingPong(0, 24), 10, fullBody: true);
final _calmClip = _Clip('idle', _pingPong(14, 24), 8, fullBody: true);
final _sleepClip = _Clip('idle', _pingPong(10, 12), 2.5, fullBody: true);
final _strongClip = _Clip('strong', _pingPong(0, 4), 8);
final _tiredClip = _Clip('tired', _pingPong(0, 18), 9);
const _happyClip = _Clip('happy', [0, 1], 0);
final _celebrateClip = _Clip('celebrate', _pingPong(0, 9), 10);

_Clip _clipFor(MascotMood mood) => switch (mood) {
  MascotMood.neutral => _idleClip,
  MascotMood.thinking || MascotMood.underweight => _calmClip,
  MascotMood.sleeping => _sleepClip,
  MascotMood.strong => _strongClip,
  MascotMood.tired => _tiredClip,
  MascotMood.happy => _happyClip,
  MascotMood.celebrate => _celebrateClip,
};

/// The GymFlow tiger ("Hổ Flow"), animated per [MascotMood].
class Mascot extends StatefulWidget {
  /// Continuous motion. Tests switch it off so frames can settle.
  static bool idleMotion = true;

  final MascotMood mood;
  final double width;

  /// Breathing glow, rays and sparkles behind the tiger.
  final bool showAura;

  /// Aura tint; defaults to the mood colour.
  final Color? auraColor;
  final bool interactive;
  const Mascot({
    super.key,
    this.mood = MascotMood.neutral,
    this.width = 140,
    this.showAura = true,
    this.auraColor,
    this.interactive = true,
  });
  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with TickerProviderStateMixin {
  /// Seconds since the mascot appeared; drives every looping motion.
  final _time = ValueNotifier<double>(0);
  Ticker? _ticker;
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool _still = false;
  int _cacheWidth = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still =
        !Mascot.idleMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (_still) {
      _ticker?.stop();
      _entrance.value = 1;
    } else {
      _ticker ??= createTicker((elapsed) {
        _time.value = elapsed.inMicroseconds / 1e6;
      });
      if (!_ticker!.isActive) _ticker!.start();
      if (_entrance.status == AnimationStatus.dismissed) _entrance.forward();
    }
    _precache();
  }

  @override
  void didUpdateWidget(covariant Mascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      if (!_still) _entrance.forward(from: 0.4);
      _precache();
    }
    if (oldWidget.width != widget.width) _precache();
  }

  // Decode only the current mood's frames, at display size, so swapping
  // frames never flashes and memory stays small.
  void _precache() {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    _cacheWidth = ((widget.width * dpr / 64).ceil() * 64).clamp(64, 512);
    for (final path in _clipFor(widget.mood).paths) {
      precacheImage(_provider(path), context, onError: (_, _) {});
    }
  }

  ImageProvider _provider(String path) =>
      ResizeImage(AssetImage(path), width: _cacheWidth, allowUpscaling: false);

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    _entrance.dispose();
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w * _aspect;
    final mood = widget.mood;
    final body = SizedBox(
      width: w,
      height: h,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_time, _entrance, _hop]),
          builder: (context, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.showAura)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _AuraPainter(
                      color: widget.auraColor ?? moodColor(mood),
                      t: _time.value,
                    ),
                  ),
                ),
              // Cross-fades for ~250 ms when the mood changes.
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _Pose(
                    key: ValueKey(mood),
                    mood: mood,
                    t: _time.value,
                    entrance: _entrance.value,
                    hop: _hop.value,
                    width: w,
                    height: h,
                    provider: _provider,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      label: 'Linh vật GymFlow: ${mood.info.label}',
      image: true,
      child: widget.interactive
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _still ? null : () => _hop.forward(from: 0),
              child: body,
            )
          : body,
    );
  }
}

/// One mood: picks the frame for time [t] and applies body motion + effects.
class _Pose extends StatelessWidget {
  final MascotMood mood;
  final double t, entrance, hop, width, height;
  final ImageProvider Function(String) provider;
  const _Pose({
    super.key,
    required this.mood,
    required this.t,
    required this.entrance,
    required this.hop,
    required this.width,
    required this.height,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final clip = _clipFor(mood);
    final m = _Motion.of(mood, t);
    final frame = mood == MascotMood.happy
        // Fists at the chest on the ground, arms up while in the air.
        ? (m.lift > 0.02 ? 1 : 0)
        : clip.frames[(t * clip.fps).floor() % clip.frames.length];

    final pop = Curves.easeOutBack.transform(entrance.clamp(0.0, 1.0));
    final tapHop = math.sin(hop * math.pi) * 0.09;
    final tapSquash = hop == 0
        ? 0.0
        : (hop < 0.15 || hop > 0.85 ? -0.05 : 0.03);
    final lift = (m.lift + tapHop) * height;
    final sx = m.scaleX - tapSquash * 0.6;
    final sy = m.scaleY + tapSquash;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (clip.fullBody) _shadow(lift / height),
        ..._behind(mood, t),
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, -lift),
            child: Transform.scale(
              scale: (0.85 + 0.15 * pop) * m.size,
              alignment: Alignment.bottomCenter,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(sx, sy, 1)..rotateZ(m.tilt),
                child: Image(
                  image: provider(clip.path(frame)),
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
        ..._effects(mood, t, entrance),
      ],
    );
  }

  Widget _shadow(double lift) {
    final s = (1 - lift * 3.5).clamp(0.6, 1.0);
    return Positioned(
      left: width * 0.24,
      right: width * 0.24,
      bottom: height * 0.004,
      height: height * 0.04,
      child: Transform.scale(
        scaleX: s,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width),
            color: const Color(0xFF1C1712).withValues(alpha: 0.14 * s),
          ),
        ),
      ),
    );
  }

  Widget _at(double x, double y, Widget child, {double opacity = 1}) =>
      Positioned(
        left: width * x,
        top: height * y,
        child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
      );

  List<Widget> _behind(MascotMood mood, double t) => switch (mood) {
    MascotMood.underweight => [
      _at(
        0.0,
        0.6,
        _Badge(Icons.rice_bowl_rounded, width * 0.2, color: AppColors.success),
      ),
    ],
    _ => const [],
  };

  List<Widget> _effects(MascotMood mood, double t, double entrance) {
    final w = width;
    double blink(double period, double offset) =>
        0.35 + 0.65 * (0.5 + 0.5 * math.sin((t / period + offset) * _tau));
    switch (mood) {
      case MascotMood.happy:
        // Three stars twinkling out of phase (0 / 0.35 / 0.6 s).
        return [
          _at(0.02, 0.1, _Star(w * 0.13), opacity: blink(1, 0)),
          _at(0.8, 0.04, _Star(w * 0.11), opacity: blink(1, 0.35)),
          _at(0.86, 0.46, _Star(w * 0.09), opacity: blink(1, 0.6)),
        ];
      case MascotMood.celebrate:
        return [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ConfettiPainter(t)),
            ),
          ),
        ];
      case MascotMood.thinking:
        final bob = math.sin(t / 3 * _tau);
        return [
          _at(0.72, 0.24, _Dot(w * 0.035), opacity: blink(1.5, 0)),
          _at(0.78, 0.15, _Dot(w * 0.05), opacity: blink(1.5, 0.3)),
          Positioned(
            left: w * 0.7,
            top: height * (-0.04 - 0.014 * bob),
            child: Transform.scale(
              scale: 1 + 0.06 * (0.5 + 0.5 * bob),
              child: _ThoughtBubble(w * 0.3),
            ),
          ),
        ];
      case MascotMood.sleeping:
        // Three Z's grow, drift up-right and fade, 1 s apart.
        return [
          for (var i = 0; i < 3; i++)
            () {
              final p = ((t + i) % 3) / 3;
              return Positioned(
                left: w * (0.66 + 0.12 * p + 0.04 * i),
                top: height * (0.3 - 0.28 * p),
                child: Opacity(
                  opacity: p < 0.3 ? p / 0.3 : 1 - (p - 0.3) / 0.7,
                  child: _Z(w * (0.12 + 0.05 * i)),
                ),
              );
            }(),
        ];
      case MascotMood.strong:
        return [
          _at(
            -0.02,
            0.4,
            _Icon(Icons.bolt_rounded, w * 0.16, AppColors.gymPointYellow),
            opacity: blink(0.9, 0),
          ),
          _at(
            0.86,
            0.36,
            _Icon(Icons.bolt_rounded, w * 0.13, AppColors.gymPointYellow),
            opacity: blink(0.9, 0.5),
          ),
        ];
      case MascotMood.underweight:
        return [
          _at(
            0.72,
            0.1,
            _Badge(
              Icons.battery_2_bar_rounded,
              w * 0.22,
              color: AppColors.info,
            ),
            opacity: blink(2, 0),
          ),
        ];
      case MascotMood.neutral || MascotMood.tired:
        return const [];
    }
  }
}

/// Body motion for one moment of a mood's loop (fractions of the height).
class _Motion {
  final double scaleX, scaleY, lift, tilt, size;
  const _Motion(
    this.scaleX,
    this.scaleY,
    this.lift,
    this.tilt, {
    this.size = 1,
  });

  static double _wave(double t, double period) =>
      0.5 - 0.5 * math.cos(t / period * _tau);
  static double _deg(double d) => d * math.pi / 180;

  static _Motion of(MascotMood mood, double t) {
    switch (mood) {
      case MascotMood.neutral:
        // Welcoming idle: breathe, lift a little and sway.
        final b = _wave(t, 2.6);
        return _Motion(
          1 + 0.01 * b,
          1 + 0.02 * b,
          0.01 * b,
          _deg(-1.5 * math.sin(t / 2.6 * _tau)),
        );
      case MascotMood.happy:
        // Squash, stretch, jump 8% and land, once per second.
        final p = t % 1.0;
        if (p < 0.15) {
          final k = p / 0.15;
          return _Motion(1.06 - 0.10 * k, 0.92 + 0.13 * k, 0, 0);
        }
        if (p < 0.85) {
          final k = (p - 0.15) / 0.7;
          final s = math.sin(k * math.pi);
          return _Motion(0.96 + 0.04 * s, 1.05 - 0.05 * s, 0.08 * s, 0);
        }
        final k = (p - 0.85) / 0.15;
        return _Motion(1 + 0.06 * k, 1 - 0.08 * k, 0, 0);
      case MascotMood.celebrate:
        final p = (t % 0.8) / 0.8;
        final s = math.sin(p * math.pi);
        return _Motion(
          1,
          1,
          0.105 * s,
          _deg(-3 * s + 3 * math.sin(t / 0.8 * _tau)),
        );
      case MascotMood.thinking:
        final b = _wave(t, 3);
        return _Motion(
          1 + 0.01 * b,
          1 + 0.015 * b,
          0,
          _deg(-0.5 + 4.5 * math.sin(t / 3 * _tau)),
        );
      case MascotMood.sleeping:
        final b = _wave(t, 3.4);
        return _Motion(
          1 + 0.015 * b,
          1 + 0.025 * b,
          -0.007 - 0.007 * b,
          _deg(4 + 2 * b),
        );
      case MascotMood.tired:
        final b = _wave(t, 0.7);
        return _Motion(1 + 0.025 * b, 1 - 0.015 * b, -0.009 * b, _deg(b));
      case MascotMood.strong:
        final b = _wave(t, 1.2);
        return _Motion(1 + 0.015 * b, 1 + 0.01 * b, 0.008 * b, 0);
      case MascotMood.underweight:
        final b = _wave(t, 2.6);
        return _Motion(1 + 0.008 * b, 1 + 0.012 * b, 0, 0, size: 0.86);
    }
  }
}

Color moodColor(MascotMood mood) => switch (mood) {
  MascotMood.happy || MascotMood.strong => AppColors.success,
  MascotMood.celebrate => AppColors.gymPointYellow,
  MascotMood.underweight => AppColors.info,
  MascotMood.thinking || MascotMood.sleeping => AppColors.purple,
  MascotMood.tired => AppColors.warning,
  MascotMood.neutral => AppColors.sunOrange,
};

/// Pale surface behind the mascot for each mood.
Color moodSoftColor(MascotMood mood) => switch (mood) {
  MascotMood.happy || MascotMood.strong => AppColors.mint,
  MascotMood.celebrate => AppColors.butter,
  MascotMood.underweight => AppColors.infoSoft,
  MascotMood.thinking || MascotMood.sleeping => AppColors.lavender,
  MascotMood.tired || MascotMood.neutral => AppColors.peach,
};

/// Breathing glow with slowly turning light rays and orbiting sparkles.
class _AuraPainter extends CustomPainter {
  final Color color;
  final double t;
  _AuraPainter({required this.color, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.56);
    final pulse = 0.5 + 0.5 * math.sin(t / 2.4 * _tau);
    final r = size.width * (0.5 + 0.04 * pulse);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.42 + 0.18 * pulse),
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Soft rays rotate a full turn every 24 s.
    final rays = Paint()..color = color.withValues(alpha: 0.10 + 0.06 * pulse);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t / 24 * _tau);
    for (var i = 0; i < 10; i++) {
      canvas.rotate(_tau / 10);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(r * 1.05, -r * 0.09)
          ..lineTo(r * 1.05, r * 0.09)
          ..close(),
        rays,
      );
    }
    canvas.restore();
    // Sparkles orbit and twinkle.
    for (var i = 0; i < 5; i++) {
      final a = t / 9 * _tau + i * _tau / 5;
      final tw = 0.5 + 0.5 * math.sin(t * 2.2 + i * 1.7);
      final p = c + Offset(math.cos(a) * r * 0.92, math.sin(a) * r * 0.78);
      canvas.drawCircle(
        p,
        size.width * (0.012 + 0.012 * tw),
        Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.55 * tw),
      );
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) => old.t != t || old.color != color;
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  const _Badge(this.icon, this.size, {this.color = AppColors.primaryOrange});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
      boxShadow: AppShadows.soft,
    ),
    child: Icon(icon, color: color, size: size * 0.55),
  );
}

class _Icon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  const _Icon(this.icon, this.size, this.color);
  @override
  Widget build(BuildContext context) => Icon(icon, size: size, color: color);
}

/// Yellow star with an ink outline.
class _Star extends StatelessWidget {
  final double size;
  const _Star(this.size);
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Icon(Icons.star_rounded, size: size * 1.18, color: AppColors.ink),
      Icon(Icons.star_rounded, size: size, color: const Color(0xFFFFD23F)),
    ],
  );
}

class _Dot extends StatelessWidget {
  final double size;
  const _Dot(this.size);
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.ink, width: 1.5),
    ),
  );
}

class _ThoughtBubble extends StatelessWidget {
  final double size;
  const _ThoughtBubble(this.size);
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size * 0.82,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size),
      border: Border.all(color: AppColors.ink, width: 2),
    ),
    child: Text(
      '?',
      style: AppTextStyles.heading1.copyWith(
        fontSize: size * 0.5,
        color: AppColors.purple,
        height: 1,
      ),
    ),
  );
}

class _Z extends StatelessWidget {
  final double size;
  const _Z(this.size);
  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.display.copyWith(fontSize: size, height: 1);
    return Stack(
      children: [
        Text(
          'Z',
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = AppColors.ink,
          ),
        ),
        Text('Z', style: style.copyWith(color: AppColors.purple)),
      ],
    );
  }
}

/// About 26 pieces falling in a loop and turning 540° on the way down.
class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);
  static const _colors = [
    AppColors.purple,
    Color(0xFFFFD23F),
    Color(0xFF2FA864),
    Color(0xFFFF5E8A),
    Color(0xFF3D7BE0),
    Colors.white,
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final period = 1.8 + random.nextDouble();
      final offset = random.nextDouble() * period;
      final x = random.nextDouble() * size.width;
      final drift = (random.nextDouble() - 0.5) * size.width * 0.3;
      final s = size.width * (0.025 + random.nextDouble() * 0.02);
      final p = ((t + offset) % period) / period;
      final fade = p > 0.8 ? (1 - p) / 0.2 : 1.0;
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: fade);
      final edge = Paint()
        ..color = AppColors.ink.withValues(alpha: 0.5 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.save();
      canvas.translate(x + drift * p, -size.height * 0.1 + p * size.height);
      canvas.rotate(p * 3 * math.pi + i);
      if (i.isEven) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: s * 1.8, height: s),
          Radius.circular(s * 0.3),
        );
        canvas.drawRRect(rect, paint);
        canvas.drawRRect(rect, edge);
      } else {
        canvas.drawCircle(Offset.zero, s * 0.6, paint);
        canvas.drawCircle(Offset.zero, s * 0.6, edge);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Mascot beside a speech card, used for health feedback and empty states.
class MascotMessage extends StatelessWidget {
  final MascotMood mood;
  final String? title;
  final String? message;
  final Widget? action;
  final double mascotWidth;
  const MascotMessage({
    super.key,
    required this.mood,
    this.title,
    this.message,
    this.action,
    this.mascotWidth = 120,
  });
  @override
  Widget build(BuildContext context) {
    final color = moodColor(mood);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Mascot(mood: mood, width: mascotWidth),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: mascotWidth * 0.18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
                bottomRight: Radius.circular(AppRadius.md),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: color.withValues(alpha: 0.3)),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (title ?? mood.info.label).toUpperCase(),
                    style: AppTextStyles.overline.copyWith(
                      color: mood == MascotMood.celebrate
                          ? AppColors.ink
                          : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(message ?? mood.info.message, style: AppTextStyles.body),
                if (action != null) ...[const SizedBox(height: 10), action!],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Floating mascot card shown for a few seconds after a milestone
/// (check-in, redemption, workout done).
void showMascotToast(
  BuildContext context, {
  required MascotMood mood,
  required String message,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _MascotToast(
      mood: mood,
      message: message,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _MascotToast extends StatefulWidget {
  final MascotMood mood;
  final String message;
  final VoidCallback onDone;
  const _MascotToast({
    required this.mood,
    required this.message,
    required this.onDone,
  });
  @override
  State<_MascotToast> createState() => _MascotToastState();
}

class _MascotToastState extends State<_MascotToast>
    with SingleTickerProviderStateMixin {
  // 3 s on screen plus enter/leave; an animation (not a Timer) so tests settle.
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _life,
    builder: (context, child) {
      final v = _life.value;
      final shown = v < 0.1
          ? Curves.easeOutBack.transform(v / 0.1)
          : v > 0.9
          ? 1 - Curves.easeIn.transform((v - 0.9) / 0.1)
          : 1.0;
      return Positioned(
        left: 20,
        right: 20,
        top: MediaQuery.paddingOf(context).top + 12 - (1 - shown) * 40,
        child: IgnorePointer(
          child: Opacity(opacity: shown.clamp(0.0, 1.0), child: child),
        ),
      );
    },
    child: Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Mascot(
              mood: widget.mood,
              width: 72,
              auraColor: AppColors.primaryOrange,
              interactive: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.message,
                style: AppTextStyles.title.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
