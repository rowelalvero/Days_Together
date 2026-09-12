import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The placeholder shown on [TimeCapsuleScreen] before any capsules exist.
/// Extracted from its `_buildEmptyState` (Migration audit item 6).
class TimeCapsuleEmptyState extends StatelessWidget {
  const TimeCapsuleEmptyState({super.key, required this.theme});

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
                color: theme.textColor.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.markunread_mailbox_outlined,
                size: 64,
                color: theme.accentColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Send a message to the future.',
              style: AppTypography.display(
                color: theme.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seal a letter today to be unlocked on a special date or milestone in your future.',
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
