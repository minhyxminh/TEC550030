import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/weight_entry.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

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
    final interval = math.max(1.0, ((maxY - minY) / 3).ceilToDouble());
    final last = visible.length - 1;
    final bar = LineChartBarData(
      spots: [
        for (var i = 0; i < visible.length; i++)
          FlSpot(i.toDouble(), visible[i].weightKg),
      ],
      color: AppColors.primaryOrange,
      barWidth: 3,
      isCurved: visible.length > 2,
      preventCurveOverShooting: true,
      showingIndicators: [last],
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, _, _, index) => FlDotCirclePainter(
          radius: index == last ? 6.5 : 4,
          color: AppColors.primaryOrange,
          strokeWidth: index == last ? 2.5 : 1.5,
          strokeColor: AppColors.ink,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryOrange.withValues(alpha: 0.18),
            AppColors.primaryOrange.withValues(alpha: 0),
          ],
        ),
      ),
    );
    final axis = AppTextStyles.caption.copyWith(fontSize: 11);
    return LayoutBuilder(
      builder: (context, c) => SizedBox(
        height: 210,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: SizedBox(
            width: math.max(c.maxWidth, visible.length * 52.0),
            height: 210,
            child: Padding(
              padding: const EdgeInsets.only(top: 34, right: 12),
              child: LineChart(
                LineChartData(
                  minX: visible.length == 1 ? -0.6 : -0.3,
                  maxX: visible.length == 1 ? 0.6 : last + 0.3,
                  minY: minY,
                  maxY: maxY,
                  borderData: FlBorderData(show: false),
                  // The band marks the range the member has moved within.
                  rangeAnnotations: RangeAnnotations(
                    horizontalRangeAnnotations: [
                      HorizontalRangeAnnotation(
                        y1: minWeight - 0.6,
                        y2: maxWeight + 0.4,
                        color: AppColors.mint.withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                  extraLinesData: ExtraLinesData(
                    verticalLines: [
                      VerticalLine(
                        x: last.toDouble(),
                        color: AppColors.primaryOrange.withValues(alpha: 0.5),
                        strokeWidth: 1.5,
                        dashArray: [3, 4],
                      ),
                    ],
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.sand,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: false,
                    getTouchedSpotIndicator: (_, indexes) => [
                      for (final _ in indexes)
                        const TouchedSpotIndicatorData(
                          FlLine(color: Colors.transparent),
                          FlDotData(show: false),
                        ),
                    ],
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.ink,
                      tooltipBorderRadius: BorderRadius.circular(10),
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      tooltipMargin: 12,
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                            '${s.y.toStringAsFixed(1)} kg',
                            AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  showingTooltipIndicators: [
                    ShowingTooltipIndicators([
                      LineBarSpot(bar, 0, bar.spots[last]),
                    ]),
                  ],
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
                        reservedSize: 36,
                        interval: interval,
                        getTitlesWidget: (v, m) => Text(
                          v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1),
                          style: axis,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
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
                              style: axis.copyWith(
                                color: i == last ? AppColors.ink : null,
                                fontWeight: i == last ? FontWeight.w700 : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [bar],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
