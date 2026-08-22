import 'package:flutter/material.dart';
import 'package:days_together/screens/wrapped/wrapped_data.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/features/wrapped/presentation/wrapped_animated_counter.dart';

class WrappedPageCapsule extends StatelessWidget {
  final WrappedData data;
  const WrappedPageCapsule({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final hasData =
        data.capsulesCreated > 0 || data.capsulesOpened > 0 || data.upcomingCapsules > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, c) => Opacity(opacity: v, child: c),
              child: const Text('🎁', style: TextStyle(fontSize: 56)),
            ),
            const SizedBox(height: 20),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              builder: (_, v, c) => Opacity(opacity: v, child: c),
              child: Text(
                'Time Capsules',
                style: AppTypography.display(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              builder: (_, v, c) => Opacity(opacity: v, child: c),
              child: Text(
                'Messages from your past selves',
                style: AppTypography.cormorant(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                ).copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            if (hasData) ...[
              Row(
                children: [
                  _buildCapsuleChip(
                    '📦',
                    data.capsulesCreated.toDouble(),
                    'Created',
                    delay: 600,
                  ),
                  const SizedBox(width: 12),
                  _buildCapsuleChip(
                    '💌',
                    data.capsulesOpened.toDouble(),
                    'Opened',
                    delay: 800,
                  ),
                  const SizedBox(width: 12),
                  _buildCapsuleChip(
                    '⏳',
                    data.upcomingCapsules.toDouble(),
                    'Upcoming',
                    delay: 1000,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (data.upcomingCapsules > 0)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1300),
                  builder: (_, v, c) => Opacity(opacity: v, child: c),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 28)),
                        const SizedBox(height: 10),
                        Text(
                          'You have ${data.upcomingCapsules} surprise${data.upcomingCapsules == 1 ? '' : 's'} waiting to be opened.',
                          style: AppTypography.body(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ] else
              _emptyCapsuleState(),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleChip(
      String emoji, double value, String label, {int delay = 0}) {
    return Expanded(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: delay),
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              WrappedAnimatedCounter(
                endValue: value,
                duration: Duration(milliseconds: 1000 + delay),
                style: AppTypography.display(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyCapsuleState() => TweenAnimationBuilder<double>(
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
                'Leave a message for future you.',
                style: AppTypography.heading(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Create a time capsule and unlock\nsomething beautiful on a future date.',
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
