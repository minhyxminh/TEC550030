import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/catalogue_media.dart';
import '../../models/membership.dart';
import '../../models/trainer.dart';
import '../../services/catalogue_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/data_view.dart';
import '../../widgets/decor.dart';
import '../../widgets/empty_state.dart';
import 'catalogue_details.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      body: PageBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: PageHeader(
                  title: 'Dịch vụ',
                  subtitle: 'Gói tập và huấn luyện viên đồng hành',
                  trailing: Sparkle(size: 18),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.lavender,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const TabBar(
                  tabs: [
                    Tab(text: 'Gói tập', height: 42),
                    Tab(text: 'Huấn luyện viên', height: 42),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
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
                            child: EmptyState(
                              message: 'Chưa có gói tập đang mở.',
                            ),
                          )
                        else
                          ...memberships.indexed.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: MembershipCard(
                                membership: entry.$2,
                                style: MembershipCard.styleAt(entry.$1),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MembershipDetailScreen(
                                      id: entry.$2.id,
                                      style: MembershipCard.styleAt(entry.$1),
                                    ),
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
                            child: EmptyState(
                              message: 'Chưa có huấn luyện viên.',
                            ),
                          )
                        else
                          ...trainers.indexed.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: AppCard(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TrainerDetailScreen(id: entry.$2.id),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    TrainerAvatar(
                                      trainer: entry.$2,
                                      index: entry.$1,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.$2.name,
                                            style: AppTextStyles.heading2,
                                          ),
                                          if (entry
                                              .$2
                                              .specialty
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            StatusPill(
                                              entry.$2.specialty,
                                              color:
                                                  tilePalette[(entry.$1 + 1) %
                                                          4]
                                                      .$2,
                                              background:
                                                  tilePalette[(entry.$1 + 1) %
                                                          4]
                                                      .$1,
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Text(
                                            '${entry.$2.experienceYears} năm kinh nghiệm',
                                            style: AppTextStyles.caption,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Text(
                                                'Xem hồ sơ',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                      color:
                                                          AppColors.deepOrange,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                size: 18,
                                                color: AppColors.deepOrange,
                                              ),
                                            ],
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
            ],
          ),
        ),
      ),
    ),
  );
}

/// Trainer photo, or a coloured rounded square with their initial.
class TrainerAvatar extends StatelessWidget {
  final Trainer trainer;
  final int index;
  final double size;
  const TrainerAvatar({
    super.key,
    required this.trainer,
    this.index = 0,
    this.size = 76,
  });
  static const _colors = [
    AppColors.primaryOrange,
    AppColors.purple,
    Color(0xFF1F7A4D),
    AppColors.ink,
  ];
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(trainer.imageUrl);
    final hasImage =
        isAssetImage(trainer.imageUrl) ||
        (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty);
    final name = trainer.name.replaceFirst(RegExp(r'^PT\s+'), '').trim();
    return SizedBox(
      width: size,
      height: size,
      child: hasImage
          ? AppImage(url: trainer.imageUrl, icon: Icons.fitness_center_rounded)
          : Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _colors[index % _colors.length],
                borderRadius: BorderRadius.circular(AppRadius.md + 4),
              ),
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: AppTextStyles.display.copyWith(
                  color: Colors.white,
                  fontSize: 30,
                ),
              ),
            ),
    );
  }
}
