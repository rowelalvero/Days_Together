import 'package:flutter/material.dart';
import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_mood_bar_chart.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_mood_empty_state.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_mood_stat_chip.dart';

/// Its inline bar chart, stat chip, and empty state were extracted into
/// widgets under `presentation/widgets/` (Migration audit item 6).
class WrappedPageMood extends StatelessWidget {
  final WrappedData data;
  const WrappedPageMood({super.key, required this.data});

  String _moodLabel(int score) {
    if (score >= 9) return '😍 Euphoric';
    if (score >= 7) return '😊 Happy';
    if (score >= 5) return '😐 Neutral';
    if (score >= 3) return '😔 Low';
    return '😢 Hard';
  }

  @override
  Widget build(BuildContext context) {
    if (!data.hasMoodData) return const WrappedMoodEmptyState();

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
                style: AppTypography.display(
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
                child: WrappedMoodBarChart(monthlyMoods: data.monthlyMoods),
              ),
            ),
            const SizedBox(height: 32),
            // Stats row
            Row(
              children: [
                WrappedMoodStatChip(
                  label: '😊 Most common',
                  value: _moodLabel(data.topMoodScore),
                  delay: 800,
                ),
                const SizedBox(width: 12),
                if (data.bestMoodMonth != null)
                  WrappedMoodStatChip(
                    label: '🌟 Best month',
                    value: data.bestMoodMonth!,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
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
}
