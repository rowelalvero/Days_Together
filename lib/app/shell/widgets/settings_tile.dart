import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// A generic icon/title/subtitle row on [SettingsTab], with a trailing
/// chevron. Extracted from its `_buildModernTile` (Migration audit item
/// 6).
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final LoveStoryTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      opacity: 0.03,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.textColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: theme.textColor.withValues(alpha: 0.7),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: AppTypography.body(
            color: theme.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.caption(
            color: theme.textColor.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: theme.textColor.withValues(alpha: 0.24),
          size: 20,
        ),
      ),
    );
  }
}
