import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/boss_battle.dart';
import '../screens/boss/boss_battle_screen.dart';
import '../services/boss_service.dart';
import 'sprite_player.dart';

String formatHp(int value) {
  final s = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
    out.write(s[i]);
  }
  return out.toString();
}

Future<void> openBossArena(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const BossBattleScreen()),
);

/// Small LIVE card on Home; the arena itself is its own screen.
class BossBanner extends StatefulWidget {
  final BossService service;
  const BossBanner({super.key, this.service = const BossService()});

  @override
  State<BossBanner> createState() => _BossBannerState();
}

class _BossBannerState extends State<BossBanner>
    with SingleTickerProviderStateMixin {
  BossBattle? _battle;
  late final AnimationController _aura = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SpritePlayer.still(context)) {
      _aura.value = 0.5;
    } else if (!_aura.isAnimating) {
      _aura.repeat();
    }
  }

  String? _error;

  Future<void> _load() async {
    try {
      final battle = await widget.service.status();
      if (mounted) {
        setState(() {
          _battle = battle;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _open() async {
    await openBossArena(context);
    _load();
  }

  @override
  void dispose() {
    _aura.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final battle = _battle;
    final month = battle?.month.month ?? DateTime.now().month;
    final subtitle = battle == null
        ? _error ?? 'Đang tải trận chiến…'
        : battle.defeated
        ? 'Boss đã bị hạ · +${battle.rewardPoints} GP đã vào ví'
        : battle.fightOpen
        ? 'Trận chiến đã mở · còn ${battle.daysLeft} ngày'
        : 'Còn ${battle.daysLeft} ngày · mỗi check-in +1 HP';
    return AnimatedBuilder(
      animation: _aura,
      builder: (context, child) {
        // Aura: a soft orange glow breathing out from the card.
        final v = _aura.value;
        final pulse = math.sin(v * math.pi);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withValues(
                  alpha: 0.18 + 0.32 * pulse,
                ),
                blurRadius: 14 + 18 * pulse,
                spreadRadius: 1 + 5 * pulse,
              ),
              BoxShadow(
                color: const Color(0xFFFF9F43)
                    .withValues(alpha: 0.25 * (1 - v)),
                blurRadius: 4,
                spreadRadius: 14 * v,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF221C38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: InkWell(
          key: const ValueKey('boss-banner'),
          onTap: _open,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2E2350), Color(0xFF1A1529)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -8,
                  bottom: -6,
                  // The sofa runs to the frame's edge: fade it into the card.
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [Colors.transparent, Colors.white],
                      stops: [0.0, 0.3],
                    ).createShader(rect),
                    child: SpritePlayer(
                      frames: bossSleepFrames,
                      fps: 5,
                      loop: SpriteLoop.pingPong,
                      stillFrame: 0,
                      width: 138,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 128, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              'BOSS THÁNG $month',
                              style: AppTextStyles.overline.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          _Live(aura: _aura),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Đại chiến Boss',
                        style: AppTextStyles.heading2.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: battle?.progress ?? 0,
                          minHeight: 9,
                          color: AppColors.primaryOrange,
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        battle == null
                            ? 'Hổ Flow – HP'
                            : 'Hổ Flow ${formatHp(battle.tigerHp)} / ${formatHp(battle.bossHp)} HP',
                        style: AppTextStyles.title.copyWith(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                // Clear tap target into the arena.
                Positioned(
                  right: 12,
                  top: 12,
                  child: Tooltip(
                    message: 'Vào đấu trường',
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryOrange.withValues(
                              alpha: 0.6,
                            ),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Live extends StatelessWidget {
  final Animation<double> aura;
  const _Live({required this.aura});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.error, width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween(
            begin: 0.25,
            end: 1.0,
          ).animate(CurvedAnimation(parent: aura, curve: const _Blink())),
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'LIVE',
          style: AppTextStyles.overline.copyWith(
            color: AppColors.error,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}

/// Blinks twice per aura cycle.
class _Blink extends Curve {
  const _Blink();
  @override
  double transformInternal(double t) => (math.sin(t * math.pi * 4) + 1) / 2;
}
