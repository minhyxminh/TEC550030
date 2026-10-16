import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../models/bmi_result.dart';
import 'measurement_ruler.dart';

class HealthMeasurement {
  final double weightKg;
  final BmiResult? bmi;
  const HealthMeasurement({required this.weightKg, this.bmi});
}

class HealthMeasurementSheet extends StatefulWidget {
  final String title;
  final BmiResult? initial;
  final double? initialWeight;
  final bool weightOnly;
  const HealthMeasurementSheet({
    super.key,
    required this.title,
    this.initial,
    this.initialWeight,
    this.weightOnly = false,
  });
  @override
  State<HealthMeasurementSheet> createState() => _HealthMeasurementSheetState();
}

class _HealthMeasurementSheetState extends State<HealthMeasurementSheet> {
  final _form = GlobalKey<FormState>();
  late double _weight, _height;
  late final TextEditingController _age;
  @override
  void initState() {
    super.initState();
    _weight = widget.initialWeight ?? widget.initial?.weightKg ?? 60;
    _height = widget.initial?.heightCm ?? 165;
    _age = TextEditingController(text: '${widget.initial?.age ?? 25}');
  }

  @override
  void dispose() {
    _age.dispose();
    super.dispose();
  }

  Widget _section(
    String label,
    String unit,
    double value,
    double min,
    double max,
    double step,
    ValueChanged<double> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value.toStringAsFixed(step < 1 ? 1 : 0),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryOrange,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      MeasurementRuler(
        key: ValueKey('ruler-$unit'),
        label: label,
        unit: unit,
        value: value,
        min: min,
        max: max,
        step: step,
        majorEvery: 10,
        onChanged: change,
      ),
    ],
  );

  void _save() {
    if (!widget.weightOnly && !_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      HealthMeasurement(
        weightKg: _weight,
        bmi: widget.weightOnly
            ? null
            : BmiResult(
                weightKg: _weight,
                heightCm: _height,
                age: int.parse(_age.text.trim()),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.weightOnly ? 340 : 540),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Kéo thước để chọn chỉ số.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              key: const ValueKey('health-sheet-content'),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section(
                      'Cân nặng',
                      'kg',
                      _weight,
                      20,
                      350,
                      0.1,
                      (v) => setState(() => _weight = v),
                    ),
                    if (!widget.weightOnly) ...[
                      const SizedBox(height: 16),
                      _section(
                        'Chiều cao',
                        'cm',
                        _height,
                        100,
                        250,
                        1,
                        (v) => setState(() => _height = v),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _age,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tuổi',
                          helperText: 'BMI dành cho người từ 20 tuổi',
                          isDense: true,
                        ),
                        validator: (value) {
                          final age = int.tryParse(value?.trim() ?? '');
                          return age == null || age < 20 || age > 120
                              ? 'Nhập tuổi từ 20 đến 120'
                              : null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: AppColors.secondaryText.withValues(alpha: 0.12),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('save-health'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _save,
                        child: const Text(
                          'Lưu chỉ số',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
