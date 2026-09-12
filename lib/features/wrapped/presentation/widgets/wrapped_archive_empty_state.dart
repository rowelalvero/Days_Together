import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The empty state shown on [WrappedArchiveScreen] when the couple has no
/// archived years yet. Extracted from its `_emptyState` method (Migration
/// audit item 6), then re-tinted to the active [LoveStoryTheme] when the
/// screen stopped painting itself a hardcoded dark.
class WrappedArchiveEmptyState extends StatelessWidget {
  const WrappedArchiveEmptyState({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📦', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 24),
            Text(
              'No archives yet',
              style: AppTypography.heading(
                fontSize: 22,
                color: theme.textColor,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Once you\'ve played through your Wrapped at\nyear\'s end, it will be saved here for you\nto revisit anytime.',
              style: AppTypography.body(
                fontSize: 15,
                color: theme.textColor.withValues(alpha: 0.45),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
