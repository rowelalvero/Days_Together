import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';

/// The "dream big together next year" state on [WrappedPageBucket] when
/// the couple has no bucket list yet. Extracted from its
/// `_emptyBucketState` method (Migration audit item 6).
class WrappedBucketEmptyState extends StatelessWidget {
  const WrappedBucketEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
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
            Text(
              'Dream big together next year.',
              style: AppTypography.heading(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add bucket list goals and start\nchecking them off one by one.',
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
