import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../models/bmi_result.dart';
import '../../models/health_guidance.dart';
import '../../models/mascot_mood.dart';
import '../../models/weight_entry.dart';
import '../../services/auth_service.dart';
import '../../services/gympoint_service.dart';
import '../../services/health_service.dart';
import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/ambient.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/bmi_scale.dart';
import '../../widgets/decor.dart';
import '../../widgets/health_measurement_sheet.dart';
import '../../widgets/weight_history_chart.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/mascot.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final _service = HealthService();
  String? _userId, _error;
  BmiResult? _result;
  List<WeightEntry> _weights = [];
  int _weeklyCheckins = 0;
  bool _loading = true, _saving = false, _editing = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await AuthService().getCurrentUser();
      final overview = await _service.overview(user.id);
      var weekly = 0;
      try {
        weekly = weeklyCheckinDays(
          await GymPointService().getHistory(limit: 30),
        );
      } catch (_) {
        /* Activity only refines the mascot; health data still loads. */
      }
      if (!mounted) return;
      setState(() {
        _userId = user.id;
        _weeklyCheckins = weekly;
        _result = overview.result;
        _weights = overview.weights;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit({bool weightOnly = false}) async {
    if (_saving || _editing) return;
    _editing = true;
    final result = await showModalBottomSheet<HealthMeasurement>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => HealthMeasurementSheet(
        title: weightOnly ? 'Ghi cân nặng' : 'Cập nhật BMI',
        initial: _result,
        initialWeight: _weights.isEmpty ? null : _weights.last.weightKg,
        weightOnly: weightOnly,
      ),
    );
    _editing = false;
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      if (result.bmi != null) {
        await _service.save(_userId!, result.bmi!);
      } else {
        await _service.saveWeight(_userId!, result.weightKg);
      }
      final overview = await _service.overview(_userId!);
      if (!mounted) return;
      setState(() {
        _result = overview.result;
        _weights = overview.weights;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu chỉ số sức khỏe hôm nay.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được chỉ số. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _heading(
    String title,
    String action,
    VoidCallback tap, {
    bool primary = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    // Wraps the button below the title on narrow screens or large text.
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text(title, style: AppTextStyles.heading1.copyWith(fontSize: 22)),
        primary
            ? FilledButton.icon(
                onPressed: _saving ? null : tap,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(action),
              )
            : OutlinedButton.icon(
                onPressed: _saving ? null : tap,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(action),
              ),
      ],
    ),
  );
  Widget _metric(
    String label,
    String value,
    IconData icon,
    Color tint,
    Color background,
  ) => AppCard(
    padding: const EdgeInsets.all(12),
    radius: AppRadius.md + 2,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(icon, color: tint, background: background, size: 30),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(label, style: AppTextStyles.caption, maxLines: 1),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppTextStyles.title.copyWith(fontSize: 17)),
        ),
      ],
    ),
  );
  Color get _bmiColor => [
    AppColors.info,
    AppColors.success,
    AppColors.warning,
    AppColors.error,
  ][_result!.categoryIndex];

  MascotMood get _mood =>
      moodForHealth(_result, weeklyCheckins: _weeklyCheckins);

  Widget _mascotCard() => HighlightCard(
    color: moodSoftColor(_mood),
    glow: moodColor(_mood),
    seed: _mood.index + 2,
    padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
    child: MascotMessage(
      key: const ValueKey('health-mascot'),
      mood: _mood,
      mascotWidth: 128,
      action: _result == null
          ? FilledButton.icon(
              onPressed: _saving ? null : () => _edit(),
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: const Text('Nhập chỉ số ngay'),
            )
          : Text(
              'Tuần này: ${_weeklyCheckins.clamp(0, 7)}/$weeklyCheckinGoal buổi tập',
              style: AppTextStyles.caption,
            ),
    ),
  );
  Widget _weightCard() {
    final latest = _weights.isEmpty ? null : _weights.last;
    final highest = _weights.isEmpty
        ? null
        : _weights.map((e) => e.weightKg).reduce(math.max);
    final lowest = _weights.isEmpty
        ? null
        : _weights.map((e) => e.weightKg).reduce(math.min);
    final change = latest == null
        ? 0.0
        : latest.weightKg - _weights.first.weightKg;
    final number = AppTextStyles.display.copyWith(
      color: Colors.white,
      fontSize: 60,
      height: 1,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            RingFrame(
              child: HighlightCard(
                color: AppColors.ink,
                glow: AppColors.purple,
                seed: 6,
                bubbleIntensity: 0.4,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.monitor_weight_outlined,
                          size: 18,
                          color: AppColors.purple,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Cân nặng hiện tại',
                            style: AppTextStyles.title.copyWith(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (latest != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: InkChip(
                              'Cập nhật ${formatDate(latest.measuredAt.toUtc().add(const Duration(hours: 7)))}',
                              background: AppColors.inkSoft,
                              foreground: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: latest == null
                          ? Text(
                              'Chưa có lần đo',
                              style: number.copyWith(fontSize: 34),
                            )
                          : Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: latest.weightKg.toStringAsFixed(1),
                                  ),
                                  TextSpan(
                                    text: ' kg',
                                    style: number.copyWith(
                                      fontSize: 24,
                                      color: AppColors.primaryOrange,
                                    ),
                                  ),
                                ],
                              ),
                              style: number,
                            ),
                    ),
                    const SizedBox(height: 14),
                    const RulerTicks(),
                    const SizedBox(height: 18),
                    AppButton(
                      text: 'Ghi cân nặng',
                      icon: Icons.add_rounded,
                      leadingIcon: true,
                      isLoading: _saving,
                      onPressed: () => _edit(weightOnly: true),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(right: -2, top: -14, child: HeartSticker()),
          ],
        ),
        if (latest != null) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _metric(
                  'Cao nhất',
                  '${highest!.toStringAsFixed(1)} kg',
                  Icons.arrow_upward_rounded,
                  AppColors.strongOrange,
                  AppColors.peach,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  'Thấp nhất',
                  '${lowest!.toStringAsFixed(1)} kg',
                  Icons.arrow_downward_rounded,
                  AppColors.info,
                  AppColors.infoSoft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  'So với lần đầu',
                  '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
                  Icons.south_east_rounded,
                  AppColors.success,
                  AppColors.mint,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text('Biểu đồ cân nặng', style: AppTextStyles.heading2),
                  const InkChip(
                    '30 lần đo gần nhất',
                    background: AppColors.field,
                    foreground: AppColors.secondaryText,
                  ),
                ],
              ),
              WeightHistoryChart(entries: _weights),
              const SizedBox(height: 6),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mỗi ngày giữ lần đo mới nhất · Biểu đồ tối đa 30 lần đo gần đây',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bmiCard() {
    final result = _result;
    if (result == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconTile(
              Icons.monitor_weight_outlined,
              background: AppColors.peach,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Hiểu cơ thể qua từng chỉ số',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 8),
            const Text(
              'Thêm cân nặng, chiều cao và tuổi để xem BMI cùng gợi ý phù hợp.',
            ),
          ],
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BMI', style: AppTextStyles.overline),
                  Text(
                    result.bmi.toStringAsFixed(1),
                    style: AppTextStyles.display.copyWith(
                      fontSize: 52,
                      color: _bmiColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: result.categoryIndex == 1
                      ? AppColors.mint
                      : _bmiColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      result.categoryIndex == 1
                          ? Icons.check_rounded
                          : Icons.info_outline_rounded,
                      size: 18,
                      color: _bmiColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        result.classification,
                        style: AppTextStyles.title.copyWith(
                          color: _bmiColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BmiScale(bmi: result.bmi),
          const SizedBox(height: 16),
          _measurementRow(
            'Chiều cao',
            '${result.heightCm.toStringAsFixed(0)} cm',
            Icons.height_rounded,
            AppColors.purple,
            AppColors.lavender,
          ),
          _measurementRow(
            'Cân nặng',
            '${result.weightKg.toStringAsFixed(1)} kg',
            Icons.monitor_weight_outlined,
            AppColors.strongOrange,
            AppColors.peach,
          ),
          _measurementRow(
            'Tuổi',
            '${result.age}',
            Icons.cake_outlined,
            AppColors.success,
            AppColors.mint,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Text(
              'BMI tham khảo cho người từ 20 tuổi. Không phản ánh riêng lượng cơ, mỡ hay các thay đổi trong thai kỳ.',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _measurementRow(
    String label,
    String value,
    IconData icon,
    Color tint,
    Color background,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: IconTile(icon, color: tint, background: background),
    title: Text(label, style: AppTextStyles.caption.copyWith(fontSize: 13)),
    subtitle: Text(value, style: AppTextStyles.title.copyWith(fontSize: 16)),
    trailing: const IconTile(
      Icons.edit_outlined,
      color: AppColors.ink,
      background: AppColors.field,
      size: 38,
    ),
    onTap: _saving ? null : () => _edit(),
  );
  List<Widget> _guidance() {
    final guidance = HealthGuidance.forResult(_result!);
    const icons = [
      Icons.directions_walk,
      Icons.restaurant_outlined,
      Icons.water_drop_outlined,
      Icons.bedtime_outlined,
      Icons.favorite_outline,
    ];
    return [
      const SizedBox(height: 28),
      Text(
        'Gợi ý sức khỏe',
        style: AppTextStyles.heading1.copyWith(fontSize: 22),
      ),
      const SizedBox(height: 12),
      HighlightCard(
        gradient: AppColors.brandGradient,
        seed: 9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(guidance.title, style: AppTextStyles.heading2),
            const SizedBox(height: 8),
            Text(guidance.summary, style: AppTextStyles.body),
          ],
        ),
      ),
      ...List.generate(
        guidance.tips.length,
        (i) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconTile(
                      icons[i],
                      color: AppColors.purple,
                      background: AppColors.lavender,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        guidance.tips[i].title,
                        style: AppTextStyles.heading2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(guidance.tips[i].content, style: AppTextStyles.body),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Gợi ý tham khảo, không phải chẩn đoán. Nội dung thay đổi theo BMI ${_result!.bmi.toStringAsFixed(1)}; mức vận động và nhu cầu ăn uống còn tùy sức khỏe thực tế.',
        style: AppTextStyles.caption,
      ),
      const SizedBox(height: 8),
      const Text(
        'Nguồn: CDC (BMI, vận động) · NHS (dinh dưỡng, kiểm soát cân nặng)',
        style: AppTextStyles.caption,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageBackdrop(
      topBlob: AppColors.mint,
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const LoadingView()
            : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      AppSpacing.navClearance,
                    ),
                    children: [
                      const PageHeader(
                        title: 'Sức khỏe',
                        subtitle: 'Theo dõi thay đổi, chăm sóc bản thân',
                      ),
                      _weightCard(),
                      const SizedBox(height: 26),
                      _mascotCard(),
                      const SizedBox(height: 20),
                      _heading(
                        'Chỉ số hiện tại',
                        _result == null ? 'Tính BMI' : 'Chỉnh sửa',
                        () => _edit(),
                        primary: false,
                      ),
                      _bmiCard(),
                      if (_result != null) ..._guidance(),
                    ],
                  ),
                ),
              ),
      ),
    ),
  );
}
