import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/form_exercise.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'form_camera_screen.dart';

class FormCheckIntroScreen extends StatelessWidget {
  final FormExercise exercise;
  const FormCheckIntroScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      appBar: AppBar(
        title: const Text('Kiểm tra chuyển động'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  exercise.displayName,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Chuẩn bị kiểm tra',
                style: AppTextStyles.heading1,
              ),
              const SizedBox(height: 6),
              const Text(
                'Đảm bảo góc đặt điện thoại phù hợp để theo dõi chuyển động chính xác nhất.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.xl),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          color: AppColors.primaryOrange,
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text('Vị trí đặt máy', style: AppTextStyles.heading2),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      exercise.positioningHint,
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: AppColors.purple,
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text('Quy trình 10 giây', style: AppTextStyles.heading2),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. Nhấn Bắt đầu và vào vị trí trong 3 giây đếm ngược.\n'
                      '2. Thực hiện 1-2 lần lặp động tác có kiểm soát trong 10 giây.\n'
                      '3. Khung xương mô phỏng sẽ hiển thị theo thời gian thực.',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              AppButton(
                text: 'Bắt đầu',
                icon: Icons.play_arrow_rounded,
                leadingIcon: false,
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FormCameraScreen(exercise: exercise),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
