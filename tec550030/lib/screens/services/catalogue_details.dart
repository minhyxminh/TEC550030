import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/catalogue_media.dart';
import '../../models/membership.dart';
import '../../models/trainer.dart';
import '../../services/catalogue_service.dart';
import 'membership_payment_screen.dart';
import 'pt_booking_screen.dart';
import '../../widgets/ambient.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/catalogue_widgets.dart';
import '../../widgets/data_view.dart';
import '../../widgets/decor.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_view.dart';
import 'services_screen.dart';

class MembershipDetailScreen extends StatelessWidget {
  final String id;

  /// Same colour as the plan's card in the list it was opened from.
  final MembershipStyle style;
  const MembershipDetailScreen({
    super.key,
    required this.id,
    this.style = MembershipStyle.light,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBackdrop(
      topBlob: AppColors.peach,
      child: SafeArea(
        bottom: false,
        child: DataView<Membership>(
          load: () => CatalogueService().getMembership(id),
          builder: (context, membership) => [
            const PageHeader(back: true, title: 'Chi tiết gói tập'),
            MembershipCard(membership: membership, style: style),
            const SizedBox(height: 24),
            const SectionTitle('Quyền lợi GymPoint'),
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconTile(
                    Icons.stars_rounded,
                    color: Color(0xFFB7791F),
                    background: AppColors.butter,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Nhận tối đa ${formatNumber(membership.pointsPerCheckin)} GP mỗi ngày có check-in hợp lệ. '
                      'Khi gói được kích hoạt, bạn nhận ${formatNumber(membership.pointsOnActivation)} GP.',
                      style: AppTextStyles.body,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(
                    Icons.qr_code_2_rounded,
                    color: AppColors.purple,
                    background: AppColors.lavender,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Thanh toán bằng QR chuyển khoản. Khi hệ thống nhận được giao dịch đúng số tiền và mã đơn, gói sẽ được kích hoạt tự động và GymPoint được cộng ngay.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  textStyle: AppTextStyles.button,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md + 2),
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MembershipPaymentScreen(membership: membership),
                  ),
                ),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Thanh toán và kích hoạt gói'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TrainerDetailScreen extends StatefulWidget {
  final String id;
  const TrainerDetailScreen({super.key, required this.id});
  @override
  State<TrainerDetailScreen> createState() => _TrainerDetailScreenState();
}

class _TrainerDetailScreenState extends State<TrainerDetailScreen> {
  late Future<Trainer> _future = CatalogueService().getTrainer(widget.id);

  void _book(Trainer trainer) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PtBookingScreen(
        trainerId: trainer.id,
        trainerName: trainer.name,
        trainerImageUrl: trainer.imageUrl,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<Trainer>(
    future: _future,
    builder: (context, snap) {
      final trainer = snap.data;
      if (trainer == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Huấn luyện viên')),
          body: snap.hasError
              ? ErrorState(
                  message: '${snap.error}',
                  onRetry: () => setState(
                    () => _future = CatalogueService().getTrainer(widget.id),
                  ),
                )
              : const LoadingView(),
        );
      }
      return Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _TrainerHero(trainer: trainer),
            Transform.translate(
              offset: const Offset(0, -64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _TrainerNameCard(trainer: trainer),
                    const SizedBox(height: 14),
                    _TrainerAbout(trainer: trainer),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          child: AppButton(
            text: 'Chọn lịch tập',
            icon: Icons.calendar_month_rounded,
            leadingIcon: true,
            onPressed: () => _book(trainer),
          ),
        ),
      );
    },
  );
}

class _TrainerHero extends StatelessWidget {
  final Trainer trainer;
  const _TrainerHero({required this.trainer});
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final uri = Uri.tryParse(trainer.imageUrl);
    final hasImage =
        isAssetImage(trainer.imageUrl) ||
        (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty);
    return SizedBox(
      height: 330 + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            child: !hasImage
                ? _fallback()
                : isAssetImage(trainer.imageUrl)
                ? Image.asset(
                    trainer.imageUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => _fallback(),
                  )
                : Image.network(
                    trainer.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallback(),
                  ),
          ),
          Positioned(left: 16, top: top + 12, child: const BackSquare()),
          Positioned(
            left: 0,
            right: 0,
            top: top + 24,
            child: const Center(
              child: InkChip('Huấn luyện viên', background: Color(0xCC1E1B2E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() => Container(
    decoration: const BoxDecoration(gradient: AppColors.brandGradient),
    child: Stack(
      children: [
        const Positioned.fill(child: AmbientBubbles(seed: 5)),
        Center(child: TrainerAvatar(trainer: trainer, index: 3, size: 120)),
      ],
    ),
  );
}

class _TrainerNameCard extends StatelessWidget {
  final Trainer trainer;
  const _TrainerNameCard({required this.trainer});
  @override
  Widget build(BuildContext context) {
    // A trailing note such as "(Yoga)" is shown in small grey type.
    final match = RegExp(r'^(.*?)\s*(\([^)]*\))\s*$').firstMatch(trainer.name);
    final name = match?.group(1) ?? trainer.name;
    final note = match?.group(2);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 64),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: name),
                      if (note != null)
                        TextSpan(
                          text: ' $note',
                          style: AppTextStyles.title.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                    ],
                  ),
                  style: AppTextStyles.heading1,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(
                    '${trainer.experienceYears} năm kinh nghiệm',
                    icon: Icons.workspace_premium_outlined,
                    color: AppColors.deepOrange,
                    background: AppColors.peach,
                  ),
                  if (trainer.specialty.isNotEmpty)
                    StatusPill(
                      trainer.specialty,
                      icon: Icons.fitness_center_rounded,
                      color: const Color(0xFF5B3FD6),
                      background: AppColors.lavender,
                    ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          right: 14,
          top: -26,
          child: Transform.rotate(
            angle: 0.14,
            child: Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD23F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.ink, width: 2.5),
                boxShadow: AppShadows.block,
              ),
              child: Text(
                'PT',
                style: AppTextStyles.heading1.copyWith(fontSize: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrainerAbout extends StatelessWidget {
  final Trainer trainer;
  const _TrainerAbout({required this.trainer});

  Widget _row(
    IconData icon,
    Color tint,
    Color background,
    String bold,
    String rest,
  ) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        IconTile(icon, color: tint, background: background, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: bold,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: rest),
              ],
            ),
            style: AppTextStyles.body,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(right: -6, top: -6, child: DotGrid(rows: 3, cols: 5)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Giới thiệu', style: AppTextStyles.heading2),
            const SizedBox(height: 10),
            Text(
              trainer.description.isEmpty
                  ? 'Huấn luyện viên chưa cập nhật phần giới thiệu.'
                  : trainer.description,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 14),
            const Divider(),
            _row(
              Icons.schedule_rounded,
              AppColors.strongOrange,
              AppColors.peach,
              '60 phút',
              ' mỗi buổi tập',
            ),
            _row(
              Icons.wb_sunny_outlined,
              AppColors.purple,
              AppColors.lavender,
              'Lịch trống ',
              'từ 06:00 đến 21:00',
            ),
            _row(
              Icons.calendar_month_rounded,
              AppColors.success,
              AppColors.mint,
              'Đặt được ',
              'trong 30 ngày tới',
            ),
          ],
        ),
      ],
    ),
  );
}
