import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The back button and title row at the top of [GiftRemindersScreen].
/// Extracted from its `_buildAppBar` (Migration audit item 6).
class GiftRemindersAppBar extends StatelessWidget {
  const GiftRemindersAppBar({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: theme.textColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gift Reminders',
                  style: AppTypography.cormorant(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  'Never forget a date. Prepare special surprises.',
                  style: AppTypography.spectral(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.7),
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
