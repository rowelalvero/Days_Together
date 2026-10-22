import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';

/// The "your story starts here" state on [WrappedPageMemories] when no
/// memory was featured. Extracted from its `_emptyMemoriesState` method
/// (Migration audit item 6).
class WrappedEmptyMemoriesState extends StatelessWidget {
  const WrappedEmptyMemoriesState({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            const Text('📷', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Your story starts here',
              style: AppTypography.heading(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add memories to your timeline\nand they\'ll live here next year.',
              style: AppTypography.body(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
