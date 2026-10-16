import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../models/bmi_result.dart';
import '../../models/health_guidance.dart';
import '../../models/weight_entry.dart';
import '../../services/auth_service.dart';
import '../../services/health_service.dart';
import '../../core/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/bmi_scale.dart';
import '../../widgets/health_measurement_sheet.dart';
import '../../widgets/weight_history_chart.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_view.dart';

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
      if (!mounted) return;
      setState(() {
        _userId = user.id;
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

  Widget _heading(String title, String action, VoidCallback tap) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
        ),
        FilledButton(onPressed: _saving ? null : tap, child: Text(action)),
      ],
    ),
  );
  Widget _metric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ],
  );
  Color get _bmiColor => [
    const Color(0xFF3B82F6),
    AppColors.success,
    AppColors.primaryOrange,
    AppColors.error,
  ][_result!.categoryIndex];
  Widget _weightCard() {
    final latest = _weights.isEmpty ? null : _weights.last;
    final highest = _weights.isEmpty
        ? null
        : _weights.map((e) => e.weightKg).reduce(math.max);
    final lowest = _weights.isEmpty
        ? null
        : _weights.map((e) => e.weightKg).reduce(math.min);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cân nặng hiện tại',
            style: TextStyle(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 6),
          Text(
            latest == null
                ? 'Chưa có lần đo'
                : '${latest.weightKg.toStringAsFixed(1)} kg',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          ),
          if (latest != null) ...[
            Text(
              'Cập nhật ${formatDate(latest.measuredAt.toUtc().add(const Duration(hours: 7)))}',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 28,
              runSpacing: 14,
              children: [
                _metric('Cao nhất', '${highest!.toStringAsFixed(1)} kg'),
                _metric('Thấp nhất', '${lowest!.toStringAsFixed(1)} kg'),
                _metric(
                  'So với lần đầu',
                  '${latest.weightKg - _weights.first.weightKg > 0 ? '+' : ''}${(latest.weightKg - _weights.first.weightKg).toStringAsFixed(1)} kg',
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          WeightHistoryChart(entries: _weights),
          const SizedBox(height: 8),
          const Text(
            'Mỗi ngày giữ lần đo mới nhất · Biểu đồ tối đa 30 lần đo gần đây',
            style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _bmiCard() {
    final result = _result;
    if (result == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.monitor_weight_outlined,
              color: AppColors.primaryOrange,
              size: 36,
            ),
            const SizedBox(height: 12),
            const Text(
              'Hiểu cơ thể qua từng chỉ số',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thêm cân nặng, chiều cao và tuổi để xem BMI cùng gợi ý phù hợp.',
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _edit(),
              child: const Text('Thêm chỉ số đầu tiên'),
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
              Text(
                result.bmi.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _bmiColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  result.classification,
                  style: TextStyle(
                    color: _bmiColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BmiScale(bmi: result.bmi),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          _measurementRow(
            'Chiều cao',
            '${result.heightCm.toStringAsFixed(0)} cm',
            Icons.height,
          ),
          _measurementRow(
            'Cân nặng',
            '${result.weightKg.toStringAsFixed(1)} kg',
            Icons.monitor_weight_outlined,
          ),
          _measurementRow('Tuổi', '${result.age}', Icons.person_outline),
          const SizedBox(height: 8),
          const Text(
            'BMI tham khảo cho người từ 20 tuổi. Không phản ánh riêng lượng cơ, mỡ hay các thay đổi trong thai kỳ.',
            style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _measurementRow(String label, String value, IconData icon) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AppColors.primaryOrange),
    title: Text(label),
    subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    trailing: const Icon(Icons.edit_outlined, size: 20),
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
      const Text(
        'Gợi ý sức khỏe',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              guidance.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.deepOrange,
              ),
            ),
            const SizedBox(height: 8),
            Text(guidance.summary),
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
                    Icon(icons[i], color: AppColors.primaryOrange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        guidance.tips[i].title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  guidance.tips[i].content,
                  style: const TextStyle(height: 1.55),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Gợi ý tham khảo, không phải chẩn đoán. Nội dung thay đổi theo BMI ${_result!.bmi.toStringAsFixed(1)}; mức vận động và nhu cầu ăn uống còn tùy sức khỏe thực tế.',
        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
      ),
      const SizedBox(height: 8),
      const Text(
        'Nguồn: CDC (BMI, vận động) · NHS (dinh dưỡng, kiểm soát cân nặng)',
        style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sức khỏe')),
    body: _loading
        ? const LoadingView()
        : _error != null
        ? ErrorState(message: _error!, onRetry: _load)
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
                children: [
                  const Text(
                    'Theo dõi thay đổi, chăm sóc bản thân',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 20),
                  _heading(
                    'Cân nặng',
                    'Ghi cân nặng',
                    () => _edit(weightOnly: true),
                  ),
                  _weightCard(),
                  const SizedBox(height: 26),
                  _heading(
                    'BMI',
                    _result == null ? 'Tính BMI' : 'Chỉnh sửa',
                    () => _edit(),
                  ),
                  _bmiCard(),
                  if (_result != null) ..._guidance(),
                ],
              ),
            ),
          ),
  );
}
