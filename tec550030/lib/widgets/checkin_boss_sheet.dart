import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/boss_battle.dart';
import '../models/mascot_mood.dart';
import '../services/boss_service.dart';
import '../services/gympoint_service.dart';
import 'boss_banner.dart';
import 'ho_flow_growth.dart';

/// After a check-in: thanks from Hổ Flow and a nudge to the boss arena.
Future<void> showCheckinBossSheet(
  BuildContext context, {
  String? branch,
  DateTime? time,
  BossService service = const BossService(),
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => CheckinBossSheet(
    branch: branch,
    time: time ?? DateTime.now(),
    service: service,
    onArena: () {
      Navigator.pop(context);
      openBossArena(context);
    },
  ),
);

class CheckinBossSheet extends StatefulWidget {
  final String? branch;
  final DateTime time;
  final BossService service;
  final VoidCallback onArena;
  const CheckinBossSheet({
    super.key,
    this.branch,
    required this.time,
    required this.service,
    required this.onArena,
  });

  @override
  State<CheckinBossSheet> createState() => _CheckinBossSheetState();
}

class _CheckinBossSheetState extends State<CheckinBossSheet> {
  BossBattle? _battle;
  String? _error;
  int? _weekly;

  @override
  void initState() {
    super.initState();
    widget.service.status().then((b) {
      if (mounted) setState(() => _battle = b);
    }, onError: (Object e) {
      if (mounted) setState(() => _error = e.toString());
    });
    GymPointService().getHistory(limit: 30).then((h) {
      if (mounted) setState(() => _weekly = weeklyCheckinDays(h));
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final b = _battle;
    final t = widget.time;
    final when =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final details = [
      ?widget.branch,
      when,
      if (_weekly != null) 'buổi $_weekly/$weeklyCheckinGoal tuần này',
    ].join(' · ');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5ED39B),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink, width: 2),
                  ),
                  child: const Icon(Icons.check_rounded, color: AppColors.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check-in thành công!',
                        style: AppTextStyles.heading2,
                      ),
                      Text(
                        details,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F1),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: const BoxDecoration(
                        color: AppColors.peach,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: b != null
                        ? _BossProgress(battle: b)
                        : SizedBox(
                            height: 120,
                            child: Center(
                              child: _error == null
                                  ? const CircularProgressIndicator(
                                      color: AppColors.primaryOrange,
                                    )
                                  : Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: FilledButton(
                key: const ValueKey('checkin-arena'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  textStyle: AppTextStyles.button,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: widget.onArena,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Xem đấu trường'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.field,
                  foregroundColor: AppColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Để sau'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BossProgress extends StatelessWidget {
  final BossBattle battle;
  const _BossProgress({required this.battle});
  @override
  Widget build(BuildContext context) {
    final b = battle;
    // The tiger grows from where it was before this check-in.
    final before = b.bossHp <= 0 ? 0.0 : ((b.tigerHp - 1) / b.bossHp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            HoFlowGrowth(progress: b.progress, from: before, width: 104),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.purple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ĐẠI CHIẾN BOSS',
                      style: AppTextStyles.overline.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bạn vừa tiếp sức cho Hổ Flow!',
                    style: AppTextStyles.title.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cảm ơn nha, tui to thêm xíu rồi nè.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'Máu Hổ',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${formatHp(b.tigerHp)} / ${formatHp(b.bossHp)} Boss',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.ink, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: before.clamp(0.0, 1.0), end: b.progress),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                color: AppColors.primaryOrange,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Hôm nay cả hệ thống +${formatHp(b.todayHp)} HP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: b.strongEnough ? AppColors.success : AppColors.ink,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                b.strongEnough ? 'Đủ sức!' : 'Thiếu ${formatHp(b.missingHp)}',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
