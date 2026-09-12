import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';

/// The "first dream of the year" card on [WrappedPageBucket]. Extracted
/// from its inline `build()` (Migration audit item 6).
class WrappedFavoriteBucketItemCard extends StatelessWidget {
  const WrappedFavoriteBucketItemCard({super.key, required this.item});

  final String item;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⭐ First dream of the year',
              style: AppTypography.caption(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.4),
                fontWeight: FontWeight.w600,
              ).copyWith(letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            Text(
              item,
              style: AppTypography.body(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
