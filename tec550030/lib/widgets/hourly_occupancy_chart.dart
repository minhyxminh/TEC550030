import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/occupancy.dart';

class HourlyOccupancyChart extends StatelessWidget {
  final List<HourlyOccupancy> data;
  final int currentHour;

  const HourlyOccupancyChart({
    super.key,
    required this.data,
    required this.currentHour,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('Chưa có dữ liệu biểu đồ', style: AppTextStyles.body),
        ),
      );
    }

    double maxY = 0;
    for (var d in data) {
      if (d.count > maxY) maxY = d.count.toDouble();
    }
    maxY = maxY < 10 ? 10 : maxY + 5;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${value.toInt()}h',
                      style: AppTextStyles.caption,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: data.map((d) {
            final isCurrentHour = d.hour == currentHour;
            return BarChartGroupData(
              x: d.hour,
              barRods: [
                BarChartRodData(
                  toY: d.count.toDouble(),
                  color: isCurrentHour
                      ? AppColors.primaryOrange
                      : AppColors.secondaryText.withValues(alpha: 0.3),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
