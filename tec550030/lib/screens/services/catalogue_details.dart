import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/membership.dart';
import '../../models/trainer.dart';
import '../../services/catalogue_service.dart';
import '../../widgets/workflow_button.dart';
import 'pt_booking_screen.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/data_view.dart';

class MembershipDetailScreen extends StatelessWidget {
  final String id;
  const MembershipDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết gói tập')),
    body: DataView<Membership>(
      load: () => CatalogueService().getMembership(id),
      builder: (context, membership) => [
        MembershipCard(membership: membership),
        const SizedBox(height: 24),
        const SectionTitle('Quyền lợi GymPoint'),
        AppCard(
          child: Text(
            'Nhận tối đa ${formatNumber(membership.pointsPerCheckin)} GP mỗi ngày có check-in hợp lệ. '
            'Khi gói được kích hoạt, bạn nhận ${formatNumber(membership.pointsOnActivation)} GP.',
            style: AppTextStyles.body,
          ),
        ),
        const SizedBox(height: 24),
        const AppCard(
          child: Text(
            'Gửi đơn đăng ký và thanh toán tại quầy. Gói tập có hiệu lực sau khi quản trị viên duyệt; thời gian còn lại của gói hiện tại được cộng tiếp.',
          ),
        ),
        const SizedBox(height: 16),
        RequestButton(
          path: '/membership-orders',
          body: {'membership_id': membership.id},
          text: 'Đăng ký gói tập',
          confirmation:
              'Đăng ký ${membership.name} với giá ${formatPrice(membership.priceVnd)}?',
          success: 'Đã gửi đơn. Vui lòng thanh toán tại quầy.',
        ),
      ],
    ),
  );
}

class TrainerDetailScreen extends StatelessWidget {
  final String id;
  const TrainerDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Huấn luyện viên')),
    body: DataView<Trainer>(
      load: () => CatalogueService().getTrainer(id),
      builder: (context, trainer) => [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: AppImage(url: trainer.imageUrl, icon: Icons.fitness_center),
        ),
        const SizedBox(height: 20),
        Text(trainer.name, style: AppTextStyles.heading1),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill('${trainer.experienceYears} năm kinh nghiệm'),
            if (trainer.specialty.isNotEmpty)
              StatusPill(trainer.specialty, color: AppColors.deepOrange),
          ],
        ),
        const SizedBox(height: 24),
        const SectionTitle('Giới thiệu'),
        AppCard(
          child: Text(
            trainer.description.isEmpty
                ? 'Huấn luyện viên chưa cập nhật phần giới thiệu.'
                : trainer.description,
            style: AppTextStyles.body,
          ),
        ),
        const SizedBox(height: 24),
        const AppCard(
          child: Text(
            'Mỗi buổi tập kéo dài 60 phút. Chọn lịch trống từ 06:00 đến 21:00 trong 30 ngày tới.',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PtBookingScreen(
                trainerId: trainer.id,
                trainerName: trainer.name,
              ),
            ),
          ),
          child: const Text('Chọn lịch tập'),
        ),
      ],
    ),
  );
}
