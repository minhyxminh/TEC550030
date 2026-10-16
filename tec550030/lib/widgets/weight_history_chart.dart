import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/weight_entry.dart';
import '../core/theme/app_colors.dart';

class WeightHistoryChart extends StatelessWidget {
  final List<WeightEntry> entries;
  const WeightHistoryChart({super.key, required this.entries});
  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Ghi lần cân đầu tiên để bắt đầu theo dõi.')),
      );
    }
    final visible = entries.length > 30
        ? entries.sublist(entries.length - 30)
        : entries;
    final minWeight = visible.map((e) => e.weightKg).reduce(math.min);
    final maxWeight = visible.map((e) => e.weightKg).reduce(math.max);
    final pad = math.max(1.0, (maxWeight - minWeight) * 0.25);
    final minY = math.max(0.0, (minWeight - pad).floorToDouble());
    final maxY = (maxWeight + pad).ceilToDouble();
    return LayoutBuilder(
      builder: (context, c) => SizedBox(
        height: 220,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: SizedBox(
            width: math.max(c.maxWidth, visible.length * 52.0),
            height: 220,
            child: LineChart(
              LineChartData(
                minX: visible.length == 1 ? -0.5 : 0,
                maxX: visible.length == 1
                    ? 0.5
                    : (visible.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1, (maxY - minY) / 4),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.secondaryText.withValues(alpha: 0.10),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: math.max(1, (maxY - minY) / 4),
                      getTitlesWidget: (v, m) => Text(
                        v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (v, m) {
                        final i = v.round();
                        if ((v - i).abs() > 0.01 ||
                            i < 0 ||
                            i >= visible.length) {
                          return const SizedBox.shrink();
                        }
                        final day = visible[i].measuredAt.toUtc().add(
                          const Duration(hours: 7),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            '${day.day}/${day.month}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < visible.length; i++)
                        FlSpot(i.toDouble(), visible[i].weightKg),
                    ],
                    color: AppColors.primaryOrange,
                    barWidth: 3,
                    isCurved: false,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primaryOrange.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
