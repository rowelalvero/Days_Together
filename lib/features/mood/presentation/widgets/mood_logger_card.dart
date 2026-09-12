import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/mood/domain/mood_presentation.dart';

/// The mood-score slider and note field on [LoveMeterScreen], shown when
/// today's mood hasn't been logged yet (or is being edited). Extracted
/// from its `_buildMoodLogger` (Migration audit item 6).
class MoodLoggerCard extends StatelessWidget {
  const MoodLoggerCard({
    super.key,
    required this.theme,
    required this.currentScore,
    required this.noteController,
    required this.onScoreChanged,
    required this.onSave,
  });

  final LoveStoryTheme theme;
  final double currentScore;
  final TextEditingController noteController;
  final ValueChanged<double> onScoreChanged;
  final VoidCallback onSave;

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'How is your mood today?',
            style: AppTypography.heading(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            moodEmojiFor(currentScore),
            style: AppTypography.body(fontSize: 70),
          ),
          const SizedBox(height: 8),
          Text(
            moodLabelFor(currentScore),
            style: AppTypography.body(
              fontSize: 16,
              color: theme.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.accentColor,
              inactiveTrackColor: theme.textColor.withValues(alpha: 0.1),
              thumbColor: theme.accentColor,
              overlayColor: theme.accentColor.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            ),
            child: Slider(
              value: currentScore,
              min: 1.0,
              max: 10.0,
              divisions: 9,
              label: currentScore.toInt().toString(),
              onChanged: onScoreChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                10,
                (i) => Text(
                  '${i + 1}',
                  style: AppTypography.caption(
                    color: (currentScore.toInt() == i + 1)
                        ? theme.textColor
                        : theme.textColor.withValues(alpha: 0.38),
                    fontWeight: (currentScore.toInt() == i + 1)
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: noteController,
            style: AppTypography.body(color: theme.textColor),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add a little detail about your day... (optional)',
              hintStyle: AppTypography.body(
                color: theme.textColor.withValues(alpha: 0.3),
              ),
              filled: true,
              fillColor: theme.textColor.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.textColor.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.accentColor),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Save Today\'s Mood',
                style: AppTypography.button(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
