import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';

/// The "no mood data yet" state on [WrappedPageMood]. Extracted from its
/// `_emptyMoodState` method (Migration audit item 6).
class WrappedMoodEmptyState extends StatelessWidget {
  const WrappedMoodEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😊', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 24),
            Text(
              'Mood Journey',
              style: AppTypography.display(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Text(
                    'How did this year feel?',
                    style: AppTypography.heading(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Use the Love Meter feature to log your daily\nmoods next year — and watch this page\ncome alive with your emotional journey.',
                    style: AppTypography.body(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.55),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
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
