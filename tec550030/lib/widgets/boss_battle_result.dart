import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import 'sprite_player.dart';

/// Shows the win or lose scene centred over the arena.
Future<void> showBossResult(
  BuildContext context, {
  required bool win,
  required int rewardPoints,
  VoidCallback? onCheckIn,
}) => showGeneralDialog(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.black.withValues(alpha: 0.72),
  transitionDuration: const Duration(milliseconds: 260),
  transitionBuilder: (context, a, _, child) => FadeTransition(
    opacity: a,
    child: ScaleTransition(
      scale: Tween(
        begin: 0.9,
        end: 1.0,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
      child: child,
    ),
  ),
  pageBuilder: (context, _, _) => Center(
    child: win
        ? BossBattleWinScene(rewardPoints: rewardPoints)
        : BossBattleLoseScene(onCheckIn: onCheckIn),
  ),
);

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      width: math.min(MediaQuery.sizeOf(context).width - 32, 360),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const RadialGradient(
          center: Alignment(0, -0.4),
          radius: 1,
          colors: [Color(0xFF3B2F63), Color(0xFF1E1B2E)],
        ),
        border: Border.all(
          color: AppColors.primaryOrange.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withValues(alpha: 0.35),
            blurRadius: 40,
          ),
        ],
      ),
      child: child,
    ),
  );
}

/// Hổ Flow knocks the boss out; coins and confetti, then the reward card.
class BossBattleWinScene extends StatefulWidget {
  static final frames = spriteFrames('battle/win', 'ho-thang', 24);

  final int rewardPoints;
  const BossBattleWinScene({super.key, required this.rewardPoints});

  @override
  State<BossBattleWinScene> createState() => _BossBattleWinSceneState();
}

class _BossBattleWinSceneState extends State<BossBattleWinScene>
    with TickerProviderStateMixin {
  // Landing (1–4) and coin burst (5–9) once, then the cheer (10–24) loops.
  static final _intro = BossBattleWinScene.frames.sublist(0, 9);
  static final _cheer = BossBattleWinScene.frames.sublist(9);
  bool _looping = false, _card = false;
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
  );
  late final _ko = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _cardTimer;

  @override
  void initState() {
    super.initState();
    _cardTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _card = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SpritePlayer.still(context)) _looping = true;
  }

  void _onFrame(int frame) {
    if (frame == 0) {
      _shake.forward(from: 0);
      _flash.forward(from: 0).then((_) => _flash.reverse());
    }
    if (frame == 4) _ko.forward(from: 0);
  }

  @override
  void dispose() {
    _cardTimer?.cancel();
    _shake.dispose();
    _flash.dispose();
    _ko.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              math.sin(_shake.value * math.pi * 8) * 6 * (1 - _shake.value),
              0,
            ),
            child: child,
          ),
          child: SizedBox(
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _looping
                    ? SpritePlayer(
                        frames: _cheer,
                        loop: SpriteLoop.loop,
                        stillFrame: 0,
                        width: 270,
                      )
                    : SpritePlayer(
                        frames: _intro,
                        loop: SpriteLoop.once,
                        width: 270,
                        onFrame: _onFrame,
                        onComplete: () => setState(() => _looping = true),
                      ),
                AnimatedBuilder(
                  animation: _ko,
                  builder: (context, _) {
                    if (!_ko.isAnimating) return const SizedBox.shrink();
                    final v = _ko.value;
                    final scale = v < 0.3
                        ? 0.4 + 1.4 * Curves.easeOutBack.transform(v / 0.3)
                        : 1.8 - 0.8 * ((v - 0.3) / 0.7);
                    return Opacity(
                      opacity: v > 0.75 ? (1 - v) / 0.25 : 1,
                      child: Transform.scale(
                        scale: scale,
                        child: Text(
                          'K.O!',
                          style: AppTextStyles.display.copyWith(
                            fontSize: 44,
                            color: const Color(0xFFFFD84D),
                            shadows: const [
                              Shadow(
                                color: AppColors.deepOrange,
                                offset: Offset(3, 3),
                              ),
                              Shadow(color: Colors.black87, blurRadius: 14),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                IgnorePointer(
                  child: FadeTransition(
                    opacity: _flash,
                    child: const ColoredBox(
                      color: Colors.white,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _SlideUp(
          shown: _card,
          child: Column(
            children: [
              Text(
                'Hạ Boss rồi! 🎉',
                style: AppTextStyles.heading1.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                'Cả cộng đồng đã nhận thưởng',
                style: AppTextStyles.body.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: _card ? widget.rewardPoints : 0),
                duration: const Duration(milliseconds: 900),
                builder: (context, v, _) => Text(
                  '+$v GP',
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.gymPointYellow,
                    fontSize: 36,
                  ),
                ),
              ),
              Text(
                'đã vào ví GymPoint của bạn',
                style: AppTextStyles.caption.copyWith(color: AppColors.butter),
              ),
              const SizedBox(height: 12),
              _ResultButton(
                label: 'Tuyệt vời!',
                icon: Icons.celebration_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The boss wins: it gloats with its trophy while Hổ Flow lies dizzy.
class BossBattleLoseScene extends StatefulWidget {
  static final frames = spriteFrames('battle/lose', 'ho-thua', 61);
  final VoidCallback? onCheckIn;
  const BossBattleLoseScene({super.key, this.onCheckIn});

  @override
  State<BossBattleLoseScene> createState() => _BossBattleLoseSceneState();
}

class _BossBattleLoseSceneState extends State<BossBattleLoseScene> {
  static final _rest = BossBattleLoseScene.frames.sublist(
    BossBattleLoseScene.frames.length - 8,
  );
  bool _resting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SpritePlayer.still(context)) _resting = true;
  }

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 250,
          child: _resting
              ? SpritePlayer(
                  frames: _rest,
                  fps: 8,
                  loop: SpriteLoop.pingPong,
                  stillFrame: 0,
                  width: 270,
                )
              : SpritePlayer(
                  frames: BossBattleLoseScene.frames,
                  loop: SpriteLoop.once,
                  width: 270,
                  onComplete: () => setState(() => _resting = true),
                ),
        ),
        _SlideUp(
          shown: _resting,
          child: Column(
            children: [
              Text(
                'Boss thắng rồi…',
                style: AppTextStyles.heading1.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'Hổ Flow cần thêm sức! Check-in thêm để phục thù vào tháng sau.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              _ResultButton(
                label: 'Check-in tiếp sức',
                icon: Icons.qr_code_scanner_rounded,
                onPressed: widget.onCheckIn,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SlideUp extends StatelessWidget {
  final bool shown;
  final Widget child;
  const _SlideUp({required this.shown, required this.child});
  @override
  Widget build(BuildContext context) => AnimatedSlide(
    offset: shown ? Offset.zero : const Offset(0, 0.4),
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutBack,
    child: AnimatedOpacity(
      opacity: shown ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(ignoring: !shown, child: child),
    ),
  );
}

class _ResultButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const _ResultButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: AppColors.ink,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.16),
        disabledForegroundColor: Colors.white,
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}
