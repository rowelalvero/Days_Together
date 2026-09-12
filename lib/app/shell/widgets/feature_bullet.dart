import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// One feature row in [PremiumPaywallSheet]. Extracted from
/// [StudioTab]'s `_buildFeatureBullet` (Migration audit item 6).
class FeatureBullet extends StatelessWidget {
  const FeatureBullet({
    super.key,
    required this.icon,
    required this.title,
    required this.desc,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String desc;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amber, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  desc,
                  style: AppTypography.bodyMedium(
                    color: theme.textColor.withValues(alpha: 0.6),
                    fontSize: 12,
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
