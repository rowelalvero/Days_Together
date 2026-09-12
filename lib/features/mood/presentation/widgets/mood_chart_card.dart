import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/mood/domain/entities/daily_mood_model.dart';

/// The 30-day mood trend line chart on [LoveMeterScreen] (or a placeholder
/// until at least 2 days are logged). Extracted from its
/// `_buildMoodChartCard` (Migration audit item 6).
class MoodChartCard extends StatelessWidget {
  const MoodChartCard({
    super.key,
    required this.recentMoods,
    required this.theme,
  });

  final List<DailyMood> recentMoods;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emotional Map',
            style: AppTypography.body(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your shared mood trends over the last 30 days',
            style: AppTypography.caption(
              fontSize: 12,
              color: theme.textColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 30),
          if (recentMoods.length < 2)
            Container(
              height: 200,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Log your mood for a few days to visualize your emotional connection 📈',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  color: theme.textColor.withValues(alpha: 0.38),
                  fontSize: 13,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: AppTypography.caption(
                              color: theme.textColor.withValues(alpha: 0.3),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: (recentMoods.length / 4).clamp(1.0, 30.0),
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < recentMoods.length) {
                            final date = DateTime.parse(recentMoods[idx].date);
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateFormat('MM/dd').format(date),
                                style: AppTypography.caption(
                                  color: theme.textColor.withValues(alpha: 0.3),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (recentMoods.length - 1).toDouble(),
                  minY: 1,
                  maxY: 10,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        recentMoods.length,
                        (index) => FlSpot(
                          index.toDouble(),
                          recentMoods[index].moodScore.toDouble(),
                        ),
                      ),
                      isCurved: true,
                      color: theme.accentColor,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 5,
                              color: theme.accentColor,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.accentColor.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
