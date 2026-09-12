import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// One toggle row on [NotificationSettingsScreen]. Extracted from its
/// `_buildSwitchTile` (Migration audit item 6).
///
/// The leading [icon] sits in the same rounded chip `SettingsTile` uses,
/// so a row here reads as the same kind of thing as a row on the Settings
/// tab it is reached from. Rows whose [onChanged] is null (muted by
/// "Mute All", or by quiet hours being off) dim their text and chip so the
/// disabled state is legible rather than only inferable from the switch.
class NotificationSwitchTile extends StatelessWidget {
  const NotificationSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;
    final titleAlpha = isEnabled ? 1.0 : 0.35;
    final subtitleAlpha = isEnabled ? 0.45 : 0.2;

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: isEnabled ? 0.05 : 0.02),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: theme.textColor.withValues(alpha: isEnabled ? 0.7 : 0.25),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: AppTypography.body(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: theme.textColor.withValues(alpha: titleAlpha),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption(
          fontSize: 12,
          color: theme.textColor.withValues(alpha: subtitleAlpha),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: theme.accentColor,
      activeTrackColor: theme.accentColor.withValues(alpha: 0.35),
      inactiveThumbColor: theme.textColor.withValues(alpha: 0.5),
      inactiveTrackColor: theme.textColor.withValues(alpha: 0.08),
    );
  }
}
