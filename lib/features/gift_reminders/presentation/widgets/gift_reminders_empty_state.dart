import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The placeholder shown on [GiftRemindersScreen] before any reminders
/// exist. Extracted from its `_buildEmptyState` (Migration audit item 6).
class GiftRemindersEmptyState extends StatelessWidget {
  const GiftRemindersEmptyState({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.card_giftcard_outlined,
                size: 64,
                color: theme.accentColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Never forget a date.',
              style: AppTypography.display(
                color: theme.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add birthdays, anniversaries, or special surprise counters.',
              textAlign: TextAlign.center,
              style: AppTypography.spectral(
                color: theme.textColor.withValues(alpha: 0.5),
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
