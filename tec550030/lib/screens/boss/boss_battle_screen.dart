import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/boss_battle.dart';
import '../../services/boss_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/boss_banner.dart';
import '../../widgets/boss_battle_cutscene.dart';
import '../../widgets/boss_battle_result.dart';
import '../../widgets/ho_flow_growth.dart';
import '../../widgets/sprite_player.dart';

const _night = Color(0xFF14111F);
const _surface = Color(0xFF241F38);

/// The boss asleep on its sofa, breathing slowly.
final bossSleepFrames = spriteFrames(
  'battle/fight/2-boss-thuc-day',
  'boss-thuc-day',
  24,
).sublist(0, 6);

String _stageName(double progress) => progress >= 1
    ? 'Chiến binh'
    : progress >= HoFlowGrowth.teen
    ? 'Hổ teen'
    : 'Hổ con';

/// Đại chiến Boss: the whole community grows Hổ Flow with check-ins and
/// fights the monthly boss together.
class BossBattleScreen extends StatefulWidget {
  final BossService service;
  const BossBattleScreen({super.key, this.service = const BossService()});

  @override
  State<BossBattleScreen> createState() => _BossBattleScreenState();
}

class _BossBattleScreenState extends State<BossBattleScreen> {
  static const _seenKey = 'boss_seen_progress';
  BossBattle? _battle;
  double? _from;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Warm the fight frames while the member reads the arena.
    BossBattleCutscene.precache(context);
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final battle = await widget.service.status();
      if (!mounted) return;
      setState(() {
        _from ??= prefs.getDouble(_seenKey);
        _battle = battle;
        _error = null;
      });
      await prefs.setDouble(_seenKey, battle.progress);
      // Boss notifications (ready to fight, boss defeated) show up right away.
      NotificationService.instance.refresh();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _fight() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final (result, battle) = await widget.service.fight();
      if (!mounted) return;
      // Decode the ending while the fight plays, so it opens without a gap.
      precacheSprites(
        context,
        result == BossFightResult.win
            ? BossBattleWinScene.frames
            : BossBattleLoseScene.frames,
        width: 270,
      );
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, _, _) =>
              BossBattleCutscene(onFinished: () => Navigator.of(context).pop()),
          transitionsBuilder: (_, a, _, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
      if (!mounted) return;
      setState(() => _battle = battle);
      await _showResult(result == BossFightResult.win);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showResult(bool win) async {
    final battle = _battle!;
    await showBossResult(
      context,
      win: win,
      rewardPoints: battle.rewardPoints,
      onCheckIn: () => Navigator.of(context).popUntil((r) => r.isFirst),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final battle = _battle;
    return Scaffold(
      backgroundColor: _night,
      body: SafeArea(
        bottom: false,
        child: battle == null
            ? _error == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryOrange,
                      ),
                    )
                  : _ErrorView(message: _error!, onRetry: _load)
            : Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          _Header(battle: battle),
                          const SizedBox(height: 14),
                          _Arena(battle: battle, from: _from),
                          const SizedBox(height: 14),
                          _GrowthTrack(battle: battle),
                          const SizedBox(height: 14),
                          _Stats(battle: battle),
                          const SizedBox(height: 20),
                          _TopBranches(battle: battle),
                        ],
                      ),
                    ),
                  ),
                  _ActionBar(
                    battle: battle,
                    busy: _busy,
                    onFight: _fight,
                    onReplay: () => _showResult(true),
                    onCheckIn: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final BossBattle battle;
  const _Header({required this.battle});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Material(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).maybePop(),
          child: const SizedBox.square(
            dimension: 48,
            child: Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          'Đại chiến Boss',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.heading1.copyWith(
            color: Colors.white,
            fontSize: 24,
            shadows: [
              Shadow(
                color: AppColors.primaryOrange.withValues(alpha: 0.8),
                blurRadius: 18,
              ),
            ],
          ),
        ),
      ),
      _Chip(
        text: 'T${battle.month.month}',
        color: AppColors.primaryOrange,
        dark: true,
      ),
      const SizedBox(width: 6),
      _Chip(
        icon: Icons.timer_outlined,
        text: battle.daysLeft <= 0 ? 'Hôm nay' : '${battle.daysLeft} ngày',
        color: Colors.white.withValues(alpha: 0.12),
      ),
    ],
  );
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final bool dark;
  const _Chip({
    required this.text,
    required this.color,
    this.icon,
    this.dark = false,
  });
  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.ink : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// HP bars, the stage and both fighters.
class _Arena extends StatelessWidget {
  final BossBattle battle;
  final double? from;
  const _Arena({required this.battle, this.from});

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 2),
      boxShadow: [
        BoxShadow(
          color: AppColors.purple.withValues(alpha: 0.35),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: CustomPaint(
      painter: _RaysPainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _HpBar(
                    label: 'Hổ Flow',
                    icon: Icons.favorite_rounded,
                    value: battle.tigerHp,
                    progress: battle.progress,
                    color: AppColors.primaryOrange,
                  ),
                ),
                const _Versus(),
                Expanded(
                  child: _HpBar(
                    label: 'Boss',
                    icon: Icons.bedtime_rounded,
                    value: battle.bossHp,
                    progress: battle.defeated ? 0 : 1,
                    color: AppColors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              battle.defeated
                  ? 'Boss đã bị hạ gục! Cả cộng đồng thắng lớn.'
                  : battle.strongEnough
                  ? 'Hổ Flow đã đủ sức! Giao chiến thôi!'
                  : 'Hổ cần thêm ${formatHp(battle.missingHp)} HP để vượt Boss',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.butter,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const _Bunting(),
            SizedBox(
              height: 250,
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  // Hổ Flow grows on stage as HP nears the boss's.
                  final tiger = w * (0.36 + 0.14 * battle.progress);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: w * 0.04,
                        right: w * 0.04,
                        bottom: 4,
                        height: 34,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.all(
                              Radius.elliptical(200, 34),
                            ),
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primaryOrange.withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -w * 0.04,
                        bottom: 0,
                        child: battle.defeated
                            ? Opacity(
                                opacity: 0.55,
                                child: Image.asset(
                                  bossSleepFrames.first,
                                  width: w * 0.58,
                                  excludeFromSemantics: true,
                                ),
                              )
                            : SpritePlayer(
                                frames: bossSleepFrames,
                                fps: 5,
                                loop: SpriteLoop.pingPong,
                                stillFrame: 0,
                                width: w * 0.58,
                              ),
                      ),
                      Positioned(
                        left: -w * 0.02,
                        bottom: 0,
                        child: HoFlowGrowth(
                          progress: battle.progress,
                          from: from,
                          width: tiger,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 4,
                        child: _Bubble(
                          battle.strongEnough
                              ? 'Sẵn sàng chiến!'
                              : 'Cố lên cả nhà ơi!',
                          color: Colors.white,
                        ),
                      ),
                      if (!battle.defeated)
                        const Positioned(
                          right: 0,
                          top: 4,
                          child: _Bubble(
                            'Ngủ thêm 5 phút...',
                            color: AppColors.lavender,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HpBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value;
  final double progress;
  final Color color;
  const _HpBar({
    required this.label,
    required this.icon,
    required this.value,
    required this.progress,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color, width: 2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              formatHp(value),
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 10,
              color: color,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Versus extends StatelessWidget {
  const _Versus();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 6),
    width: 38,
    height: 38,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.gymPointYellow,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.ink, width: 2),
      boxShadow: [
        BoxShadow(
          color: AppColors.gymPointYellow.withValues(alpha: 0.6),
          blurRadius: 14,
        ),
      ],
    ),
    child: Text(
      'VS',
      style: AppTextStyles.title.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  final String text;
  final Color color;
  const _Bubble(this.text, {required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.ink, width: 1.5),
    ),
    child: Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Bunting extends StatelessWidget {
  const _Bunting();
  static const _colors = [
    AppColors.primaryOrange,
    AppColors.purple,
    Color(0xFF4CC38A),
    AppColors.gymPointYellow,
    Color(0xFF3B7BF0),
  ];
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 22,
    child: CustomPaint(size: Size.infinite, painter: _BuntingPainter(_colors)),
  );
}

class _BuntingPainter extends CustomPainter {
  final List<Color> colors;
  _BuntingPainter(this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    const n = 11;
    final step = size.width / n;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), line);
    for (var i = 0; i < n; i++) {
      final x = i * step;
      final path = Path()
        ..moveTo(x + 2, 0)
        ..lineTo(x + step - 2, 0)
        ..lineTo(x + step / 2, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = colors[i % colors.length].withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BuntingPainter old) => false;
}

/// Dark combat backdrop with an orange burst behind the fighters.
class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E2350), Color(0xFF1A1529)],
        ).createShader(rect),
    );
    final center = Offset(size.width / 2, size.height * 0.68);
    final ray = Paint()
      ..color = AppColors.primaryOrange.withValues(alpha: 0.10);
    for (var i = 0; i < 18; i++) {
      final a = i * math.pi / 9;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(a - 0.08) * size.longestSide,
          center.dy + math.sin(a - 0.08) * size.longestSide,
        )
        ..lineTo(
          center.dx + math.cos(a + 0.08) * size.longestSide,
          center.dy + math.sin(a + 0.08) * size.longestSide,
        )
        ..close();
      canvas.drawPath(path, ray);
    }
    canvas.drawCircle(
      center,
      size.width * 0.45,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                AppColors.primaryOrange.withValues(alpha: 0.28),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: size.width * 0.45),
            ),
    );
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => false;
}

/// Hổ con → Hổ teen → Chiến binh.
class _GrowthTrack extends StatelessWidget {
  final BossBattle battle;
  const _GrowthTrack({required this.battle});
  @override
  Widget build(BuildContext context) {
    final p = battle.progress;
    final steps = [for (final (name, at, _) in _stages) (name, at)];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hổ Flow đang là',
                  style: AppTextStyles.body.copyWith(color: Colors.white70),
                ),
              ),
              Text(
                _stageName(p),
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.primaryOrange,
                ),
              ),
            ],
          ),
          Text(
            'Chạm vào từng giai đoạn để xem Hổ Flow lớn lên',
            style: AppTextStyles.caption.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              const dot = 30.0, label = 76.0;
              final track = box.maxWidth - dot;
              return SizedBox(
                height: 58,
                child: Stack(
                  // The stage halos reach past the track.
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: dot / 2,
                      right: dot / 2,
                      top: dot / 2 - 3,
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: p,
                          color: AppColors.primaryOrange,
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                    for (final (i, (name, at)) in steps.indexed)
                      Positioned(
                        // Each label is centred on its milestone, kept inside.
                        left: (dot / 2 + track * at - label / 2).clamp(
                          0.0,
                          box.maxWidth - label,
                        ),
                        top: 0,
                        width: label,
                        // Tap a stage to watch Hổ Flow grow into it.
                        child: GestureDetector(
                          key: ValueKey('growth-stage-$i'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _showStage(context, battle, i),
                          child: Column(
                            crossAxisAlignment: i == 0
                                ? CrossAxisAlignment.start
                                : i == 2
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.center,
                            children: [
                              _StagePulse(
                                phase: i / _stages.length,
                                lit: p >= at,
                                size: dot,
                                child: Container(
                                  width: dot,
                                  height: dot,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: p >= at
                                        ? AppColors.gymPointYellow
                                        : _surface,
                                    border: Border.all(
                                      color: p >= at
                                          ? AppColors.ink
                                          : Colors.white38,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    '${i + 1}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: p >= at
                                          ? AppColors.ink
                                          : Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                name,
                                maxLines: 1,
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Growth stages: name, HP share needed, and the frame that shows it best.
const _stages = [
  ('Hổ con', 0.0, 0.0),
  ('Hổ teen', HoFlowGrowth.teen, 0.42),
  ('Chiến binh', 1.0, 1.0),
];

/// Hổ Flow grows from a cub into the chosen stage, centred over the arena.
Future<void> _showStage(BuildContext context, BossBattle battle, int i) {
  final (name, share, look) = _stages[i];
  final needed = (battle.bossHp * share).ceil();
  final reached = battle.tigerHp >= needed;
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 240),
    transitionBuilder: (context, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(
          begin: 0.92,
          end: 1.0,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
    pageBuilder: (context, _, _) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: math.min(MediaQuery.sizeOf(context).width - 32, 340),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1,
              colors: [Color(0xFF3B2F63), Color(0xFF1E1B2E)],
            ),
            border: Border.all(
              color: AppColors.primaryOrange.withValues(alpha: 0.6),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Giai đoạn ${i + 1} · $name',
                style: AppTextStyles.heading2.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: Center(
                  child: HoFlowGrowth(
                    key: ValueKey('stage-preview-$i'),
                    progress: look,
                    from: 0,
                    width: 230,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                i == 0 ? 'Khởi đầu mỗi tháng' : 'Cần ${formatHp(needed)} HP',
                style: AppTextStyles.title.copyWith(color: AppColors.butter),
              ),
              const SizedBox(height: 4),
              Text(
                reached
                    ? 'Hổ Flow đã đạt giai đoạn này ✓'
                    : 'Còn thiếu ${formatHp(needed - battle.tigerHp)} HP',
                style: AppTextStyles.caption.copyWith(
                  color: reached ? const Color(0xFF5ED39B) : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: AppColors.ink,
                    textStyle: AppTextStyles.button,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Soft breathing aura and a ring spreading out from a stage dot, so it
/// reads as something to tap.
class _StagePulse extends StatefulWidget {
  final double phase, size;
  final bool lit;
  final Widget child;
  const _StagePulse({
    required this.phase,
    required this.lit,
    required this.size,
    required this.child,
  });
  @override
  State<_StagePulse> createState() => _StagePulseState();
}

class _StagePulseState extends State<_StagePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SpritePlayer.still(context)) {
      _pulse.value = 0.4;
    } else if (!_pulse.isAnimating) {
      // Staggered so the three dots light up one after another.
      _pulse.value = widget.phase;
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.lit
        ? AppColors.gymPointYellow
        : const Color(0xFFFF9F43);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final v = _pulse.value;
        final breath = math.sin(v * math.pi);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Spreading hollow ring, drawn outside so the layout stays put.
            Positioned(
              left: -9 * v,
              top: -9 * v,
              right: -9 * v,
              bottom: -9 * v,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: glow.withValues(alpha: 0.7 * (1 - v)),
                    width: 2,
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.25 + 0.35 * breath),
                    blurRadius: 8 + 8 * breath,
                    spreadRadius: 1 + 2 * breath,
                  ),
                ],
              ),
              child: child,
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color color;
  const _Card({required this.child, this.color = _surface});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: child,
  );
}

class _Stats extends StatelessWidget {
  final BossBattle battle;
  const _Stats({required this.battle});
  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value, Color tint) => Expanded(
      child: _Card(
        color: tint.withValues(alpha: 0.16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTextStyles.heading2.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        tile('Mỗi check-in', '+1 HP', AppColors.primaryOrange),
        const SizedBox(width: 8),
        tile('Bạn đã góp', '${formatHp(battle.myHp)} HP', AppColors.purple),
        const SizedBox(width: 8),
        tile(
          'Thắng boss',
          '+${battle.rewardPoints} GP',
          const Color(0xFF4CC38A),
        ),
      ],
    );
  }
}

class _TopBranches extends StatelessWidget {
  final BossBattle battle;
  const _TopBranches({required this.battle});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.gymPointYellow,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Chi nhánh góp sức nhiều nhất',
              style: AppTextStyles.title.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (battle.topBranches.isEmpty)
        Text(
          'Chưa có lượt check-in nào tháng này. Hãy là người mở màn!',
          style: AppTextStyles.body.copyWith(color: Colors.white60),
        )
      else
        Row(
          children: [
            for (final (i, b) in battle.topBranches.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _Card(
                  color: i == 0
                      ? AppColors.gymPointYellow.withValues(alpha: 0.18)
                      : _surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: [
                                AppColors.gymPointYellow,
                                const Color(0xFFC9CED8),
                                const Color(0xFFE39A62),
                              ][i.clamp(0, 2)],
                            ),
                            child: Text(
                              '${i + 1}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (i == 0) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.military_tech_rounded,
                              size: 18,
                              color: AppColors.gymPointYellow,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${formatHp(b.hp)} HP',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      const SizedBox(height: 6),
      Text(
        'Chi nhánh có nhiều lượt check-in nhất cuối tháng được vinh danh.',
        style: AppTextStyles.caption.copyWith(color: Colors.white54),
      ),
    ],
  );
}

class _ActionBar extends StatelessWidget {
  final BossBattle battle;
  final bool busy;
  final VoidCallback onFight, onReplay, onCheckIn;
  const _ActionBar({
    required this.battle,
    required this.busy,
    required this.onFight,
    required this.onReplay,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    // A win already paid the reward; the button replays the celebration.
    final (label, icon, action) = battle.defeated
        ? (
            'Đã hạ Boss · +${battle.rewardPoints} GP đã vào ví',
            Icons.emoji_events_rounded,
            onReplay,
          )
        : battle.fightOpen
        ? ('GIAO CHIẾN!', Icons.sports_mma_rounded, onFight)
        : ('Check-in tiếp sức', Icons.qr_code_scanner_rounded, onCheckIn);
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                key: const ValueKey('boss-action'),
                style: FilledButton.styleFrom(
                  backgroundColor: battle.fightOpen && !battle.defeated
                      ? AppColors.primaryOrange
                      : Colors.white,
                  foregroundColor: AppColors.ink,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.14),
                  disabledForegroundColor: Colors.white70,
                  textStyle: AppTextStyles.button.copyWith(fontSize: 17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: busy ? null : action,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon),
                label: Text(label),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white54, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
