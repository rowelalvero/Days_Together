import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/mood/domain/entities/daily_mood_model.dart';
import 'package:days_together/features/mood/domain/mood_presentation.dart';

/// The read-only summary of today's already-logged mood on
/// [LoveMeterScreen], with an "Update" button to re-open the logger.
/// Extracted from its `_buildTodayMoodSummary` (Migration audit item 6).
class TodayMoodSummaryCard extends StatelessWidget {
  const TodayMoodSummaryCard({
    super.key,
    required this.todayMood,
    required this.theme,
    required this.onUpdate,
  });

  final DailyMood todayMood;
  final LoveStoryTheme theme;
  final VoidCallback onUpdate;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Mood',
                style: AppTypography.body(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor.withValues(alpha: 0.7),
                ),
              ),
              TextButton.icon(
                onPressed: onUpdate,
                icon: const Icon(Icons.edit, size: 16),
                label: Text(
                  'Update',
                  style: AppTypography.button(color: theme.accentColor),
                ),
                style: TextButton.styleFrom(foregroundColor: theme.accentColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                moodEmojiFor(todayMood.moodScore.toDouble()),
                style: AppTypography.body(fontSize: 48),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score: ${todayMood.moodScore}/10',
                      style: AppTypography.body(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      moodLabelFor(todayMood.moodScore.toDouble()),
                      style: AppTypography.body(
                        fontSize: 14,
                        color: theme.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (todayMood.note != null && todayMood.note!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '"${todayMood.note}"',
                style: AppTypography.body(
                  color: theme.textColor.withValues(alpha: 0.7),
                  fontSize: 14,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
