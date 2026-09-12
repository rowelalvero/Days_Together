import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// One feature card in [StudioTab]'s list (AI Love Letter Generator,
/// Future Time Capsule, Relationship Insights). Extracted from its
/// `_buildStudioCard` (Migration audit item 6).
class StudioCard extends StatelessWidget {
  const StudioCard({
    super.key,
    required this.icon,
    required this.title,
    required this.desc,
    required this.isPremium,
    required this.isUnlocked,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String desc;
  final bool isPremium;
  final bool isUnlocked;
  final LoveStoryTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isPremium && !isUnlocked
                ? Colors.amber.withValues(alpha: 0.2)
                : theme.textColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (isPremium && !isUnlocked
                            ? Colors.amber
                            : theme.accentColor)
                        .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isPremium && !isUnlocked
                    ? Colors.amber
                    : theme.accentColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: AppTypography.body(
                          color: theme.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (isPremium) ...[
                        const SizedBox(width: 8),
                        Icon(
                          isUnlocked
                              ? Icons.star_rounded
                              : Icons.lock_outline_rounded,
                          color: isUnlocked
                              ? Colors.amber
                              : theme.textColor.withValues(alpha: 0.54),
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: AppTypography.bodyMedium(
                      color: theme.textColor.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
