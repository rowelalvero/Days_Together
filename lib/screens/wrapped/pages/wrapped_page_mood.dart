import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:days_together/screens/wrapped/wrapped_data.dart';
import 'package:days_together/themes/app_typography.dart';

class WrappedPageMood extends StatelessWidget {
  final WrappedData data;
  const WrappedPageMood({super.key, required this.data});

  static const _monthAbbr = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _moodLabel(int score) {
    if (score >= 9) return '😍 Euphoric';
    if (score >= 7) return '😊 Happy';
    if (score >= 5) return '😐 Neutral';
    if (score >= 3) return '😔 Low';
    return '😢 Hard';
  }

  @override
  Widget build(BuildContext context) {
    if (!data.hasMoodData) return _emptyMoodState();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(36, 24, 36, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Text(
                'Mood Journey',
                style: AppTypography.mainCounter(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Text(
                'Your emotional year at a glance',
                style: AppTypography.cormorant(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 36),
            // Bar chart
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: SizedBox(
                height: 180,
                child: _buildBarChart(),
              ),
            ),
            const SizedBox(height: 32),
            // Stats row
            Row(
              children: [
                _buildStatChip(
                  '😊 Most common',
                  _moodLabel(data.topMoodScore),
                  delay: 800,
                ),
                const SizedBox(width: 12),
                if (data.bestMoodMonth != null)
                  _buildStatChip(
                    '🌟 Best month',
                    data.bestMoodMonth!,
                    delay: 1000,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1200),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Text(
                      '💕 Avg mood score',
                      style: AppTypography.body(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const Spacer(),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: data.avgMoodScore),
                      duration: const Duration(milliseconds: 1400),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, child) => Text(
                        '${v.toStringAsFixed(1)} / 10',
                        style: AppTypography.body(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final moods = data.monthlyMoods;
    final maxY = 10.0;

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                      fontWeight: FontWeight.w500),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(12, (i) {
          final month = i + 1;
          final mood =
              moods.where((m) => m.month == month).firstOrNull;
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
                      ? [
                          const Color(0xFF3949AB),
                          const Color(0xFF7986CB),
                        ]
                      : [
                          Colors.white10,
                          Colors.white10,
                        ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, {int delay = 0}) {
    return Expanded(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: delay),
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                ).copyWith(letterSpacing: 0.3),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: AppTypography.body(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyMoodState() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😊', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 24),
            Text(
              'Mood Journey',
              style: AppTypography.mainCounter(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Text(
                    'How did this year feel?',
                    style: AppTypography.sectionHeader(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Use the Love Meter feature to log your daily\nmoods next year — and watch this page\ncome alive with your emotional journey.',
                    style: AppTypography.body(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.55),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
