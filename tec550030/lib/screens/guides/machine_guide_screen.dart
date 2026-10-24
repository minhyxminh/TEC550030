import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/machine_guide.dart';
import 'guide_video_screen.dart';
import '../../widgets/app_card.dart';
import '../../widgets/machine_guide_card.dart';

Future<void> watchGuide(BuildContext context, MachineGuide guide) async {
  if (guide.youtubeId == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Video đang được cập nhật.')));
    return;
  }
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => GuideVideoScreen(guide: guide)),
  );
}

class MachineGuideScreen extends StatelessWidget {
  final MachineGuide guide;
  const MachineGuideScreen({super.key, required this.guide});

  Widget _section(
    String title,
    IconData icon,
    List<String> items, {
    bool numbered = false,
    Color color = AppColors.primaryOrange,
  }) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(title, style: AppTextStyles.heading2),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: numbered
                      ? Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        )
                      : Icon(Icons.circle, size: 7, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(items[i], style: AppTextStyles.body)),
              ],
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(guide.name)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            GestureDetector(
              onTap: () => watchGuide(context, guide),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: MachineThumbnail(
                  guide: guide,
                  radius: AppRadius.xl,
                  large: true,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(guide.subtitle, style: AppTextStyles.heading2),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Meta(Icons.schedule_rounded, guide.durationLabel),
                _Meta(Icons.signal_cellular_alt_rounded, guide.level.label),
                _Meta(Icons.repeat_rounded, guide.prescription),
              ],
            ),
            const SizedBox(height: 12),
            MuscleTags(guide.muscles),
            const SizedBox(height: AppSpacing.lg),
            if (guide.videoUrl != null)
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => watchGuide(context, guide),
                  icon: const Icon(Icons.play_circle_rounded),
                  label: const Text('Xem video hướng dẫn'),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.ondemand_video_rounded, color: AppColors.info),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Video đang được cập nhật. Trong lúc chờ, bạn làm theo các bước bên dưới nhé.',
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            _section('Chuẩn bị', Icons.tune_rounded, guide.setup),
            const SizedBox(height: AppSpacing.md),
            _section(
              'Thực hiện',
              Icons.directions_run_rounded,
              guide.steps,
              numbered: true,
            ),
            const SizedBox(height: AppSpacing.md),
            _section(
              'Lỗi thường gặp',
              Icons.warning_amber_rounded,
              guide.mistakes,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Bắt đầu với mức tạ nhẹ và nhờ huấn luyện viên kiểm tra tư thế trong vài buổi đầu.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.sand),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.primaryOrange),
        const SizedBox(width: 5),
        Flexible(child: Text(text, style: AppTextStyles.caption)),
      ],
    ),
  );
}

class MachineGuideListScreen extends StatelessWidget {
  const MachineGuideListScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bài tập nổi bật')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          itemCount: machineGuides.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            if (i == 0) {
              return const Text(
                'Xem nhanh cách dùng máy trước khi tập',
                style: AppTextStyles.caption,
              );
            }
            final guide = machineGuides[i - 1];
            return AppCard(
              padding: const EdgeInsets.all(10),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MachineGuideScreen(guide: guide),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    height: 84,
                    child: MachineThumbnail(guide: guide),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(guide.name, style: AppTextStyles.title),
                        const SizedBox(height: 2),
                        Text(guide.subtitle, style: AppTextStyles.caption),
                        const SizedBox(height: 8),
                        MuscleTags(guide.muscles, max: 2),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
