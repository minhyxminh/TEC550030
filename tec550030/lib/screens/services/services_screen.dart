import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dịch vụ & Gói tập')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gói tập (Membership)', style: AppTextStyles.heading1),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gói Basic', style: AppTextStyles.heading2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Đang xử lý',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('500.000đ / tháng', style: AppTextStyles.body),
                  const SizedBox(height: 16),
                  const Text(
                    '• Tích lũy 10 GP mỗi lần Check-in\n• Truy cập tất cả các chi nhánh',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text('Huấn luyện viên (PT)', style: AppTextStyles.heading1),
            const SizedBox(height: 16),
            AppCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primaryOrange,
                    child: Icon(Icons.fitness_center, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Trần Văn B', style: AppTextStyles.heading2),
                        const SizedBox(height: 4),
                        Text(
                          'Chuyên gia giảm cân',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
