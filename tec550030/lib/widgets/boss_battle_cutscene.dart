import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import 'sprite_player.dart';

class _Scene {
  final List<String> frames;
  final double fps;
  final int repeats;

  /// Close-up that fills its frame: shown inside a rounded card.
  final bool fullBleed;
  final bool brawl;
  const _Scene(
    this.frames, {
    this.fps = 24,
    this.repeats = 1,
    this.fullBleed = false,
    this.brawl = false,
  });
}

String _fight(String folder) => 'battle/fight/$folder';

/// One frame of the whole fight, and when it starts.
class _Shot {
  final String path;
  final int scene;
  final double start;
  const _Shot(this.path, this.scene, this.start);
}

/// Hổ Flow vs the boss, played like one continuous video, then [onFinished].
class BossBattleCutscene extends StatefulWidget {
  static final scenes = [
    _Scene(spriteFrames(_fight('1-ho-dam-boc'), 'ho-dam-boc', 27)),
    _Scene(spriteFrames(_fight('2-boss-thuc-day'), 'boss-thuc-day', 24)),
    // Close-ups are only a few frames: slower so they register.
    _Scene(spriteFrames(_fight('3-ho-can-mat'), 'ho-can-mat', 6), fps: 10),
    _Scene(
      spriteFrames(_fight('4-boss-can-mat'), 'boss-can-mat', 7),
      fps: 10,
      fullBleed: true,
    ),
    _Scene(spriteFrames(_fight('5-lao-vao-nhau'), 'lao-vao-nhau', 13)),
    _Scene(
      spriteFrames(_fight('6-dam-may-danh-nhau'), 'dam-may-danh-nhau', 19),
      repeats: 3,
      brawl: true,
    ),
  ];

  static Iterable<String> get allFrames => scenes.expand((s) => s.frames);

  /// Decoded size of the fight frames; small enough for all to stay cached.
  static const maxPixels = 400;

  /// Decodes every frame; the arena calls it early so the fight starts
  /// without a wait.
  static Future<void> precache(BuildContext context) =>
      precacheSprites(context, allFrames, width: 440, maxPixels: maxPixels);

  final VoidCallback onFinished;
  const BossBattleCutscene({super.key, required this.onFinished});

  @override
  State<BossBattleCutscene> createState() => _BossBattleCutsceneState();
}

class _BossBattleCutsceneState extends State<BossBattleCutscene>
    with TickerProviderStateMixin {
  // The whole fight as one timeline, so frames follow each other with no gap.
  static final List<_Shot> _timeline = () {
    final shots = <_Shot>[];
    var t = 0.0;
    for (final (i, scene) in BossBattleCutscene.scenes.indexed) {
      for (var r = 0; r < scene.repeats; r++) {
        for (final path in scene.frames) {
          shots.add(_Shot(path, i, t));
          t += 1 / scene.fps;
        }
      }
    }
    shots.add(_Shot(shots.last.path, shots.last.scene, t)); // end marker
    return shots;
  }();

  late final Ticker _ticker = createTicker(_tick);
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  int _shot = 0;
  bool _ready = false, _finished = false, _still = false;
  final _pops = <_Pop>[];
  Timer? _popTimer;
  final _random = math.Random();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready || _finished) return;
    _still = SpritePlayer.still(context);
    if (_still) {
      // One dust-cloud frame instead of the whole fight.
      _ready = true;
      Timer(const Duration(seconds: 1), _finish);
      return;
    }
    BossBattleCutscene.precache(context).then((_) {
      if (!mounted || _finished) return;
      setState(() => _ready = true);
      _ticker.start();
    });
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _ticker.stop();
    _popTimer?.cancel();
    widget.onFinished();
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    var shot = _shot;
    while (shot + 1 < _timeline.length && _timeline[shot + 1].start <= t) {
      shot++;
    }
    if (shot >= _timeline.length - 1) {
      _finish();
      return;
    }
    if (shot == _shot) return;
    final before = _timeline[_shot].scene;
    final now = _timeline[shot].scene;
    setState(() => _shot = shot);
    if (now != before) _enterScene(BossBattleCutscene.scenes[now]);
  }

  void _enterScene(_Scene scene) {
    if (scene.fullBleed || scene.brawl) _shake.repeat(count: 2);
    if (scene.brawl) {
      _popTimer?.cancel();
      _popTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
        if (!mounted) return;
        setState(() {
          _pops.removeWhere((p) => p.age > 3);
          for (final p in _pops) {
            p.age++;
          }
          _pops.add(
            _Pop(
              _random.nextBool() ? 'BÙM!' : 'PẰNG!',
              Offset(
                _random.nextDouble() * 0.7 + 0.15,
                _random.nextDouble() * 0.5 + 0.2,
              ),
              (_random.nextDouble() - 0.5) * 0.5,
            ),
          );
        });
        _shake.forward(from: 0);
      });
    } else {
      _popTimer?.cancel();
      _pops.clear();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _popTimer?.cancel();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final size = math.min(screen.width - 24, 440.0);
    final shot = _still
        ? _Shot(BossBattleCutscene.scenes.last.frames[10], 5, 0)
        : _timeline[_shot];
    final fullBleed = BossBattleCutscene.scenes[shot.scene].fullBleed;
    return Material(
      color: const Color(0xFF110E1C),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _Stage(),
          if (!_ready)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            )
          else
            AnimatedBuilder(
              animation: _shake,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  math.sin(_shake.value * math.pi * 6) * 6 * (1 - _shake.value),
                  math.cos(_shake.value * math.pi * 5) * 3 * (1 - _shake.value),
                ),
                child: child,
              ),
              // The same image widget for every frame: no blank between shots.
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: size,
                  height: size,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: fullBleed
                          ? AppColors.primaryOrange
                          : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      if (fullBleed)
                        BoxShadow(
                          color: AppColors.purple.withValues(alpha: 0.5),
                          blurRadius: 30,
                        ),
                    ],
                  ),
                  child: Image(
                    image: spriteProvider(
                      context,
                      440,
                      maxPixels: BossBattleCutscene.maxPixels,
                    )(shot.path),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          for (final p in _pops)
            Positioned(
              left: p.at.dx * screen.width - 50,
              top: p.at.dy * screen.height,
              child: _PopText(key: ObjectKey(p), pop: p),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton.icon(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                  ),
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Bỏ qua'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pop {
  final String text;
  final Offset at;
  final double tilt;
  int age = 0;
  _Pop(this.text, this.at, this.tilt);
}

class _PopText extends StatelessWidget {
  final _Pop pop;
  const _PopText({super.key, required this.pop});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 380),
    curve: Curves.elasticOut,
    builder: (context, v, child) => Opacity(
      opacity: v.clamp(0.0, 1.0),
      child: Transform.rotate(
        angle: pop.tilt,
        child: Transform.scale(scale: 0.4 + 0.8 * v, child: child),
      ),
    ),
    child: Text(
      pop.text,
      style: AppTextStyles.display.copyWith(
        fontSize: 40,
        color: const Color(0xFFFFD84D),
        shadows: const [
          Shadow(color: AppColors.deepOrange, offset: Offset(3, 3)),
          Shadow(color: Colors.black54, blurRadius: 12),
        ],
      ),
    ),
  );
}

/// Dark arena backdrop: spotlight and orange/purple glows.
class _Stage extends StatelessWidget {
  const _Stage();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -0.1),
        radius: 0.9,
        colors: [
          AppColors.purple.withValues(alpha: 0.35),
          AppColors.primaryOrange.withValues(alpha: 0.12),
          const Color(0xFF110E1C),
        ],
        stops: const [0, 0.45, 1],
      ),
    ),
  );
}
