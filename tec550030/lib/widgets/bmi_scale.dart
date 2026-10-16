import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';

class BmiScale extends StatelessWidget {
  final double bmi;
  const BmiScale({super.key, required this.bmi});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Thang BMI từ 15 đến 40; chỉ số hiện tại ${bmi.toStringAsFixed(1)}',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fraction = ((bmi - 15) / 25).clamp(0.0, 1.0);
        const bounds = [15.0, 16.0, 18.5, 25.0, 30.0, 35.0, 40.0];
        const colors = [
          Color(0xFF60A5FA),
          Color(0xFF3B82F6),
          AppColors.success,
          AppColors.gymPointYellow,
          AppColors.primaryOrange,
          AppColors.error,
        ];
        return SizedBox(
          height: 78,
          child: Stack(
            children: [
              Positioned(
                left: (fraction * width - 7).clamp(0, width - 14),
                top: 0,
                child: const Icon(
                  Icons.arrow_drop_down,
                  size: 22,
                  color: AppColors.darkText,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 25,
                child: Row(
                  children: List.generate(
                    6,
                    (i) => Expanded(
                      flex: ((bounds[i + 1] - bounds[i]) * 10).round(),
                      child: Container(
                        height: 14,
                        margin: EdgeInsets.only(right: i == 5 ? 0 : 3),
                        decoration: BoxDecoration(
                          color: colors[i],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ...List.generate(bounds.length, (i) {
                final label = bounds[i].toStringAsFixed(i == 2 ? 1 : 0);
                final x = (bounds[i] - 15) / 25 * width;
                // Keep the two close lower-end labels on alternate baselines.
                return Positioned(
                  left: (x - 12).clamp(0, width - 28),
                  top: i == 1 ? 59 : 43,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    ),
  );
}
