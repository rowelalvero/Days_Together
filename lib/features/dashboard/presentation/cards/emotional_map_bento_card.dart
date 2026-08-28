import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/mood/daily_mood_controller.dart';
import 'package:days_together/features/mood/daily_mood_state.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Bento card for the Emotional Wave Map / Mood Trend analysis on the dashboard.
class EmotionalMapBentoCard extends StatelessWidget {
  final LoveStoryTheme theme;

  const EmotionalMapBentoCard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final dailyMood = ref.watch(dailyMoodControllerProvider);
        final isPaired = ref.watch(sessionControllerProvider).isPaired;

        return InkWell(
          onTap: () => context.push(Routes.loveMeter),
          borderRadius: BorderRadius.circular(24),
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'EMOTIONAL TREND',
                        style: AppTypography.cardCategory(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: theme.accentColor,
                        ).copyWith(letterSpacing: 0.5),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.trending_up_rounded,
                          color: theme.accentColor,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Emotional Wave Map',
                      style: AppTypography.title(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.textColor,
                      ),
                    ),
                    if (isPaired)
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'You',
                            style: AppTypography.caption(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: theme.textColor.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.textColor.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Partner',
                            style: AppTypography.caption(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: theme.textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildEmotionalMapContent(context, dailyMood),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '30-Day Trend Analysis',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.captionMono(
                          fontSize: 10,
                          color: theme.textColor.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Text(
                          'View Mood Map',
                          style: AppTypography.button(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: theme.accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: theme.accentColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmotionalMapContent(
    BuildContext context,
    DailyMoodState dailyMood,
  ) {
    final recent = dailyMood.recentMoods;
    final partnerRecent = dailyMood.partnerRecentMoods;

    if (recent.length < 2) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Log your mood for a few days to see your emotional map',
          textAlign: TextAlign.center,
          style: AppTypography.caption(
            fontSize: 11,
            color: theme.textColor.withValues(alpha: 0.38),
          ).copyWith(fontStyle: FontStyle.italic),
        ),
      );
    }

    final now = DateTime.now();
    final dates = List.generate(
      7,
      (i) => DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: 6 - i))),
    );

    final userMoodsMap = {for (var m in recent) m.date: m.moodScore};
    final partnerMoodsMap = {for (var m in partnerRecent) m.date: m.moodScore};

    final userSpots = <FlSpot>[];
    final partnerSpots = <FlSpot>[];

    for (int i = 0; i < dates.length; i++) {
      final date = dates[i];
      if (userMoodsMap.containsKey(date)) {
        userSpots.add(FlSpot(i.toDouble(), userMoodsMap[date]!.toDouble()));
      }
      if (partnerMoodsMap.containsKey(date)) {
        partnerSpots.add(FlSpot(i.toDouble(), partnerMoodsMap[date]!.toDouble()));
      }
    }

    return SizedBox(
      height: 150,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, right: 12.0),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: theme.textColor.withValues(alpha: 0.05),
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 2.5,
                  getTitlesWidget: (value, meta) {
                    String emoji = '';
                    if (value == 10) {
                      emoji = '😄';
                    } else if (value == 7.5) {
                      emoji = '🙂';
                    } else if (value == 5.0) {
                      emoji = '😐';
                    } else if (value == 2.5) {
                      emoji = '😢';
                    } else if (value == 0.0) {
                      emoji = '😭';
                    }

                    if (emoji.isEmpty) return const SizedBox.shrink();
                    return Text(emoji, style: const TextStyle(fontSize: 12));
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx >= 0 && idx < dates.length) {
                      final dateStr = dates[idx];
                      try {
                        final date = DateTime.parse(dateStr);
                        final label = DateFormat('E').format(date);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: AppTypography.captionMono(
                              fontSize: 9,
                              color: theme.textColor.withValues(alpha: 0.4),
                            ),
                          ),
                        );
                      } catch (_) {}
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: 6,
            minY: 0,
            maxY: 10,
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (touchedSpot) =>
                    theme.backgroundColor.withValues(alpha: 0.95),
                tooltipBorder: BorderSide(
                  color: theme.textColor.withValues(alpha: 0.1),
                  width: 1,
                ),
                tooltipRoundedRadius: 12,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((barSpot) {
                    final score = barSpot.y.toInt();
                    final isUser = barSpot.barIndex == 0;
                    final label = isUser ? 'You' : 'Partner';
                    final scoreEmoji = score >= 9
                        ? '😄'
                        : score >= 7
                        ? '🙂'
                        : score >= 5
                        ? '😐'
                        : score >= 3
                        ? '😢'
                        : '😭';
                    return LineTooltipItem(
                      '$label: $scoreEmoji ($score)',
                      TextStyle(
                        color: isUser
                            ? theme.accentColor
                            : theme.textColor.withValues(alpha: 0.7),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              if (userSpots.isNotEmpty)
                LineChartBarData(
                  spots: userSpots,
                  isCurved: true,
                  color: theme.accentColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 3.5,
                          color: theme.accentColor,
                          strokeWidth: 1.0,
                          strokeColor: Colors.white,
                        ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        theme.accentColor.withValues(alpha: 0.15),
                        theme.accentColor.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              if (partnerSpots.isNotEmpty)
                LineChartBarData(
                  spots: partnerSpots,
                  isCurved: true,
                  color: theme.textColor.withValues(alpha: 0.2),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 3.5,
                          color: theme.textColor.withValues(alpha: 0.3),
                          strokeWidth: 1.0,
                          strokeColor: Colors.white,
                        ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        theme.textColor.withValues(alpha: 0.05),
                        theme.textColor.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
