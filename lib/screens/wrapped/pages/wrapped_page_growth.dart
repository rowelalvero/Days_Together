import 'package:flutter/material.dart';
import 'package:days_together/screens/wrapped/wrapped_data.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/widgets/wrapped/wrapped_animated_counter.dart';

class WrappedPageGrowth extends StatelessWidget {
  final WrappedData data;
  const WrappedPageGrowth({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final units = [
      _GrowthUnit(
        emoji: '🗓️',
        value: data.durationYears.toDouble(),
        label: data.durationYears == 1 ? 'Year' : 'Years',
        delay: 0,
      ),
      _GrowthUnit(
        emoji: '🌙',
        value: data.durationMonths.toDouble(),
        label: data.durationMonths == 1 ? 'Month' : 'Months',
        delay: 150,
      ),
      _GrowthUnit(
        emoji: '☀️',
        value: data.durationDays.toDouble(),
        label: data.durationDays == 1 ? 'Day' : 'Days',
        delay: 300,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Text(
                'Your love has grown for',
                style: AppTypography.cormorant(
                  fontSize: 26,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ).copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
            ...units.map((u) => _buildRow(u)),
            const SizedBox(height: 48),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOut,
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Text(
                  '"Every day with you is a gift I never want to stop unwrapping."',
                  style: AppTypography.cormorant(
                    fontSize: 17,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w400,
                  ).copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(_GrowthUnit u) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 700 + u.delay),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, 30 * (1 - v)),
        child: Opacity(opacity: v, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(u.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WrappedAnimatedCounter(
                    endValue: u.value,
                    duration: Duration(milliseconds: 1200 + u.delay),
                    style: AppTypography.display(
                      fontSize: 48,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    u.label,
                    style: AppTypography.body(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w400,
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

class _GrowthUnit {
  final String emoji;
  final double value;
  final String label;
  final int delay;
  const _GrowthUnit({
    required this.emoji,
    required this.value,
    required this.label,
    required this.delay,
  });
}
