import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';

/// One achieved-milestone row on [WrappedPageMilestones]. Extracted from
/// its `_buildMilestoneTile` method (Migration audit item 6) -- [index]
/// staggers the tile's entrance animation.
class WrappedMilestoneTile extends StatelessWidget {
  const WrappedMilestoneTile({
    super.key,
    required this.title,
    required this.index,
  });

  final String title;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 700 + index * 150),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - v)),
        child: Opacity(opacity: v, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.body(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
