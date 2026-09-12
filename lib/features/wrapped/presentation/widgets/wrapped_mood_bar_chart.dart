import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:days_together/features/wrapped/domain/wrapped_data.dart';

const _monthAbbr = [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The monthly mood-score bar chart on [WrappedPageMood]. Extracted from
/// its `_buildBarChart` method (Migration audit item 6).
class WrappedMoodBarChart extends StatelessWidget {
  const WrappedMoodBarChart({super.key, required this.monthlyMoods});

  final List<MonthlyMood> monthlyMoods;

  @override
  Widget build(BuildContext context) {
    const maxY = 10.0;

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final month = value.toInt();
                if (month < 1 || month > 12) return const SizedBox();
                return Text(
                  _monthAbbr[month],
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(12, (i) {
          final month = i + 1;
          final mood = monthlyMoods.where((m) => m.month == month).firstOrNull;
          final score = mood?.avgScore ?? 0.0;
          return BarChartGroupData(
            x: month,
            barRods: [
              BarChartRodData(
                toY: score,
                width: 14,
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: score > 0
                      ? [const Color(0xFF3949AB), const Color(0xFF7986CB)]
                      : [Colors.white10, Colors.white10],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
