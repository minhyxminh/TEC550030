import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/form_check_result.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'form_camera_screen.dart';

class FormResultScreen extends StatelessWidget {
  final FormCheckResult result;
  const FormResultScreen({super.key, required this.result});

  Color get _scoreColor {
    if (result.score >= 90) return AppColors.success;
    if (result.score >= 75) return AppColors.primaryOrange;
    if (result.score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(
        title: const Text('Kết quả Form Check'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            // Score Banner Card
            AppCard(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.ink, AppColors.inkSoft],
              ),
              child: Column(
                children: [
                  Text(
                    'FORM SCORE',
                    style: AppTextStyles.overline.copyWith(
                      color: Colors.white54,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${result.score}',
                        style: TextStyle(
                          fontFamily: AppTextStyles.brandFont,
                          fontSize: 78,
                          fontWeight: FontWeight.w800,
                          color: _scoreColor,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 6),
                        child: Text(
                          '/ 100',
                          style: AppTextStyles.heading2.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _scoreColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      result.rating.label,
                      style: TextStyle(
                        color: _scoreColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Metrics Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chỉ số vận động', style: AppTextStyles.heading2),
                  const SizedBox(height: 14),
                  for (final m in result.metrics)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(m.label, style: AppTextStyles.body),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                m.value,
                                style: AppTextStyles.title.copyWith(
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                              if (m.quality != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '· ${m.quality}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            if (result.feedback.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nhận xét', style: AppTextStyles.heading2),
                    const SizedBox(height: 12),
                    for (final f in result.feedback)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.tips_and_updates_rounded,
                                size: 18,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(f, style: AppTextStyles.body)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            AppButton(
              text: 'Thử lại',
              icon: Icons.refresh_rounded,
              leadingIcon: true,
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => FormCameraScreen(exercise: result.exercise),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              text: 'Về bài hướng dẫn',
              isSecondary: true,
              onPressed: () {
                // Return to the MachineGuideScreen
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
