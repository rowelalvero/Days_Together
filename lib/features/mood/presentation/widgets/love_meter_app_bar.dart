import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The back button and title row at the top of [LoveMeterScreen].
/// Extracted from its `_buildAppBar` (Migration audit item 6).
class LoveMeterAppBar extends StatelessWidget {
  const LoveMeterAppBar({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: theme.textColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Love Harmony',
                style: AppTypography.cormorant(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              Text(
                'Connect your hearts and share your daily moods.',
                style: AppTypography.spectral(
                  fontSize: 12,
                  color: theme.textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
