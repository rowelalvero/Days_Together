import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The day-detail row shown when the selected day is the couple's
/// anniversary. Extracted from [CalendarScreen]'s `_buildAnniversaryCard`
/// (Migration audit item 6).
class CalendarAnniversaryCard extends StatelessWidget {
  const CalendarAnniversaryCard({
    super.key,
    required this.theme,
    required this.years,
  });

  final LoveStoryTheme theme;

  /// Years since the couple's start date; 0 is the anniversary of the start
  /// date itself.
  final int years;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.accentColor.withValues(alpha: 0.3),
            theme.accentColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.textColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('💑', style: AppTypography.body(fontSize: 18)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  years == 0 ? 'The Day We Met' : '$years Year Anniversary',
                  style: AppTypography.body(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'A very special day in our story.',
                  style: AppTypography.caption(
                    color: theme.textColor.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
