import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';

/// The "your next milestone is coming" state on [WrappedPageMilestones]
/// when the couple hasn't hit one this year. Extracted from its
/// `_emptyMilestonesState` method (Migration audit item 6).
class WrappedMilestonesEmptyState extends StatelessWidget {
  const WrappedMilestonesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(
              'Your next milestone is coming.',
              style: AppTypography.heading(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Every day brings you closer to something\nworth celebrating.',
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
