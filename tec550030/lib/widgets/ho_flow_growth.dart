import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import 'sprite_player.dart';

/// Hổ Flow growing from cub to champion as its HP nears the boss's.
class HoFlowGrowth extends StatefulWidget {
  static final frames = spriteFrames('mascot/grow', 'ho-flow-lon-len', 97);

  /// Milestones: teen at a third, champion when HP matches the boss.
  static const teen = 0.33;

  /// Tiger HP / boss HP, 0.0 → 1.0.
  final double progress;

  /// Where the tiger was last time, so the member watches it grow.
  final double? from;
  final double width;

  const HoFlowGrowth({
    super.key,
    required this.progress,
    this.from,
    this.width = 180,
  });

  static int frameFor(double progress) =>
      (progress.clamp(0.0, 1.0) * 96).round();

  @override
  State<HoFlowGrowth> createState() => _HoFlowGrowthState();
}

class _HoFlowGrowthState extends State<HoFlowGrowth>
    with TickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  double _time = 0;
  double _lastTick = 0;
  double _shown = 0; // fractional frame while growing
  int _target = 0;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _target = HoFlowGrowth.frameFor(widget.progress);
    _shown = HoFlowGrowth.frameFor(widget.from ?? widget.progress).toDouble();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheSprites(context, HoFlowGrowth.frames, width: widget.width);
    _still = SpritePlayer.still(context);
    if (_still) {
      _ticker.stop();
      _shown = _target.toDouble();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant HoFlowGrowth oldWidget) {
    super.didUpdateWidget(oldWidget);
    _target = HoFlowGrowth.frameFor(widget.progress);
    if (_still) _shown = _target.toDouble();
  }

  void _tick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    final dt = (now - _lastTick).clamp(0.0, 0.1);
    _lastTick = now;
    final before = _shown;
    if (_shown < _target) {
      _shown = math.min(_target.toDouble(), _shown + dt * 24);
    } else if (_shown > _target) {
      _shown = math.max(_target.toDouble(), _shown - dt * 24);
    }
    // Level-up burst when passing the teen and champion milestones.
    final teen = HoFlowGrowth.frameFor(HoFlowGrowth.teen);
    if ((before < teen && _shown >= teen) || (before < 96 && _shown >= 96)) {
      _pulse.forward(from: 0);
    }
    setState(() => _time = now);
  }

  int get _frame {
    final growing = _shown != _target;
    if (_still || growing) return _shown.round();
    if (_target >= 96) {
      // Champion: flexes in a loop, ready to fight.
      const first = 80, last = 96;
      const period = 2 * (last - first);
      final p = (_time * 12).floor() % period;
      return p <= last - first ? first + p : last - (p - (last - first));
    }
    // Idle: breathes between the current frame and the few before it.
    final low = math.max(0, _target - 3);
    final span = _target - low;
    if (span == 0) return _target;
    final p = (_time * 6).floor() % (2 * span);
    return p <= span ? low + p : _target - (p - span);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bob = _still ? 0.0 : math.sin(_time * 2 * math.pi / 2.4) * 4;
    final frame = widget.width;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final v = _pulse.value;
        final scale = _pulse.isAnimating
            ? 1 + 0.08 * Curves.elasticOut.transform(v) * (1 - v)
            : 1.0;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (_pulse.isAnimating)
              Container(
                width: frame * (0.8 + 0.5 * v),
                height: frame * (0.8 + 0.5 * v),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF9F43).withValues(alpha: 0.7 * (1 - v)),
                      const Color(0xFFFF9F43).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(0, -bob),
              child: Transform.scale(scale: scale, child: child),
            ),
          ],
        );
      },
      child: Image(
        image: spriteProvider(context, frame)(HoFlowGrowth.frames[_frame]),
        width: frame,
        height: frame,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => SizedBox.square(dimension: frame),
      ),
    );
  }
}
