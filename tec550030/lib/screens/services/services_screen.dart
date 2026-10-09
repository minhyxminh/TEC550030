import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/membership.dart';
import '../../models/trainer.dart';
import '../../services/catalogue_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/data_view.dart';
import '../../widgets/empty_state.dart';
import 'catalogue_details.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Dịch vụ'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Gói tập'),
            Tab(text: 'Huấn luyện viên'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          DataView<List<Membership>>(
            load: CatalogueService().getMemberships,
            builder: (context, memberships) => [
              const SectionTitle(
                'Chọn gói phù hợp',
                subtitle: 'Giá, thời hạn và quyền lợi GymPoint',
              ),
              if (memberships.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: EmptyState(message: 'Chưa có gói tập đang mở.'),
                )
              else
                ...memberships.map(
                  (membership) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: MembershipCard(
                      membership: membership,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MembershipDetailScreen(id: membership.id),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          DataView<List<Trainer>>(
            load: CatalogueService().getTrainers,
            builder: (context, trainers) => [
              const SectionTitle(
                'Đồng hành cùng chuyên gia',
                subtitle: 'Khám phá chuyên môn và kinh nghiệm của PT',
              ),
              if (trainers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: EmptyState(message: 'Chưa có huấn luyện viên.'),
                )
              else
                ...trainers.map(
                  (trainer) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AppCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TrainerDetailScreen(id: trainer.id),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 72,
                            height: 88,
                            child: AppImage(
                              url: trainer.imageUrl,
                              icon: Icons.fitness_center,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trainer.name,
                                  style: AppTextStyles.heading2,
                                ),
                                if (trainer.specialty.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    trainer.specialty,
                                    style: AppTextStyles.body,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  '${trainer.experienceYears} năm kinh nghiệm',
                                  style: AppTextStyles.caption,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Xem hồ sơ',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primaryOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
