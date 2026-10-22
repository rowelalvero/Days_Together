import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_animated_counter.dart';

/// The "N dreams completed this year" card on [WrappedPageBucket].
/// Extracted from its inline `build()` (Migration audit item 6).
class WrappedBucketCompletedCard extends StatelessWidget {
  const WrappedBucketCompletedCard({
    super.key,
    required this.completedThisYear,
    required this.year,
  });

  final int completedThisYear;
  final int year;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - v)),
        child: Opacity(opacity: v, child: child),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            const Text('✅', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WrappedAnimatedCounter(
                    endValue: completedThisYear.toDouble(),
                    duration: const Duration(milliseconds: 1400),
                    style: AppTypography.display(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    completedThisYear == 1
                        ? 'dream completed in $year'
                        : 'dreams completed in $year',
                    style: AppTypography.body(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
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
