import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';

class TimeWindowChart extends StatelessWidget {
  const TimeWindowChart({
    super.key,
    required this.windows,
    required this.desiredDepartureAt,
  });

  final List<TimeWindow> windows;
  final DateTime desiredDepartureAt;

  @override
  Widget build(BuildContext context) {
    if (windows.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No time windows returned.')),
      );
    }

    final sorted = [...windows]
      ..sort((a, b) => a.departureAt.compareTo(b.departureAt));

    final scheme = Theme.of(context).colorScheme;
    final recommendedColor = scheme.primary;
    final otherColor = scheme.secondaryContainer;
    final onOther = scheme.onSecondaryContainer;

    // Nearest bar to the user's desired departure — outlined so users can
    // see, at a glance, how much they save by shifting.
    final desiredIndex = _indexClosestTo(sorted, desiredDepartureAt);

    final maxMinutes = sorted
        .map((w) => w.estimatedMinutes)
        .reduce((a, b) => a > b ? a : b);
    final yMax = (maxMinutes * 1.15).ceilToDouble();
    final fmt = DateFormat.Hm();

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, right: 8),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: yMax,
            barGroups: [
              for (var i = 0; i < sorted.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: sorted[i].estimatedMinutes,
                      width: 18,
                      color: sorted[i].recommended
                          ? recommendedColor
                          : otherColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                      borderSide: i == desiredIndex && !sorted[i].recommended
                          ? BorderSide(color: scheme.primary, width: 2)
                          : BorderSide.none,
                    ),
                  ],
                  showingTooltipIndicators:
                      sorted[i].recommended ? const [0] : const [],
                ),
            ],
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}m',
                    style: TextStyle(color: onOther, fontSize: 11),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= sorted.length) {
                      return const SizedBox.shrink();
                    }
                    final isDesired = i == desiredIndex;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        fmt.format(sorted[i].departureAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isDesired ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: scheme.outlineVariant,
                strokeWidth: 0.5,
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, __) {
                  final w = sorted[group.x];
                  return BarTooltipItem(
                    '${fmt.format(w.departureAt)}\n'
                    '${w.estimatedMinutes.toStringAsFixed(0)} min · '
                    '×${w.trafficFactor.toStringAsFixed(2)}',
                    TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  static int _indexClosestTo(List<TimeWindow> sorted, DateTime target) {
    var bestIndex = 0;
    var bestDelta = sorted.first.departureAt.difference(target).abs();
    for (var i = 1; i < sorted.length; i++) {
      final delta = sorted[i].departureAt.difference(target).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}
