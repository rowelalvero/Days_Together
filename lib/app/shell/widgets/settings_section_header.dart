import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// A small caps section heading on [SettingsTab] ("EXPERIENCE",
/// "CONNECTION"). Extracted from its `_buildSectionHeader` (Migration
/// audit item 6).
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({
    super.key,
    required this.title,
    required this.theme,
  });

  final String title;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
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
