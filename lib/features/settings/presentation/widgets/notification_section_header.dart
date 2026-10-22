import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// A section heading on [NotificationSettingsScreen] ("GLOBAL
/// PREFERENCES", "QUIET HOURS", "FEATURE NOTIFICATIONS"). Extracted from
/// its `_buildSectionHeader` (Migration audit item 6).
///
/// Deliberately mirrors `SettingsSectionHeader`'s small-caps treatment
/// rather than importing it: this screen is a Settings destination and
/// should read as one, but a feature reaching into `app/shell/widgets/`
/// would invert the same boundary love_story_screen.dart's timeline
/// imports did.
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
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption(
          color: theme.textColor.withValues(alpha: 0.3),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ).copyWith(letterSpacing: 2),
      ),
    );
  }
}
