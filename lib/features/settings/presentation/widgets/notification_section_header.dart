import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// A section heading on [NotificationSettingsScreen] ("Global
/// Preferences", "Quiet Hours", "Feature Notifications"). Extracted from
/// its `_buildSectionHeader` (Migration audit item 6).
class NotificationSectionHeader extends StatelessWidget {
  const NotificationSectionHeader({
    super.key,
    required this.title,
    required this.theme,
  });

  final String title;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: AppTypography.bodyLarge(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: theme.textColor.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
