import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The DATE/TIME picker row on [GenesisScreen]. Extracted from its
/// `_buildPickerTile` method (Migration audit item 6).
class DateTimePickerTile extends StatelessWidget {
  const DateTimePickerTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final LoveStoryTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: theme.accentColor),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor.withValues(alpha: 0.5),
                  ).copyWith(letterSpacing: 2),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.body(
                    color: theme.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.edit_rounded,
              color: theme.textColor.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
