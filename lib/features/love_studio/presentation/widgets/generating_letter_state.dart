import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "writing your love story" loading state on [AILoveLetterScreen].
/// Extracted from its `_buildGeneratingState` method (Migration audit
/// item 6).
class GeneratingLetterState extends StatelessWidget {
  const GeneratingLetterState({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: theme.accentColor),
            const SizedBox(height: 24),
            Text(
              '✍️ Writing your love story...',
              style: AppTypography.body(
                color: theme.textColor.withValues(alpha: 0.7),
                fontSize: 16,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
