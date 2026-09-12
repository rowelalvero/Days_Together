import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// One toggle row on [NotificationSettingsScreen]. Extracted from its
/// `_buildSwitchTile` (Migration audit item 6).
class NotificationSwitchTile extends StatelessWidget {
  const NotificationSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        title,
        style: AppTypography.body(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: theme.textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption(
          fontSize: 12,
          color: theme.textColor.withValues(alpha: 0.54),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: theme.accentColor,
      inactiveTrackColor: theme.textColor.withValues(alpha: 0.1),
    );
  }
}
