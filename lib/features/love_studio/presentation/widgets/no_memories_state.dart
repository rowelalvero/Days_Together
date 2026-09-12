import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The empty state shown on [AILoveLetterScreen] when the couple has no
/// timeline memories yet. Extracted from its `_buildNoMemoriesState` method
/// (Migration audit item 6).
class NoMemoriesState extends StatelessWidget {
  const NoMemoriesState({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.palette_outlined,
              size: 64,
              color: theme.textColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No memories logged yet',
              style: AppTypography.title(color: theme.textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Share a memory in the Timeline first, and we\'ll help you turn it into a beautiful love letter.',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                color: theme.textColor.withValues(alpha: 0.54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
