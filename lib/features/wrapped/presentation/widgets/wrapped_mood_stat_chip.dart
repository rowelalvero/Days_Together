import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';

/// One fading-in stat chip (e.g. "Most common" / "Best month") on
/// [WrappedPageMood]. Extracted from its `_buildStatChip` method
/// (Migration audit item 6).
class WrappedMoodStatChip extends StatelessWidget {
  const WrappedMoodStatChip({
    super.key,
    required this.label,
    required this.value,
    this.delay = 0,
  });

  final String label;
  final String value;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: delay),
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                ).copyWith(letterSpacing: 0.3),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: AppTypography.body(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
