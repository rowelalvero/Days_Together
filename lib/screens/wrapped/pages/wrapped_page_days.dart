import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:days_together/screens/wrapped/wrapped_data.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/widgets/wrapped/wrapped_animated_counter.dart';

class WrappedPageDays extends StatelessWidget {
  final WrappedData data;
  const WrappedPageDays({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Text(
                'You spent',
                style: AppTypography.cormorant(
                  fontSize: 28,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFF43F5E), Color(0xFFFF9A9E), Color(0xFFFAD0C4)],
              ).createShader(bounds),
              child: WrappedAnimatedCounter(
                endValue: data.totalDays.toDouble(),
                duration: const Duration(milliseconds: 1800),
                formatter: (v) => NumberFormat('#,###').format(v),
                style: AppTypography.display(
                  fontSize: 96,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Text(
                'beautiful days together',
                style: AppTypography.cormorant(
                  fontSize: 30,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
            if (data.startDate != null) ...[
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOut,
                builder: (_, v, child) => Opacity(opacity: v, child: child),
                child: Column(
                  children: [
                    Text(
                      'Since',
                      style: AppTypography.body(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('MMMM d, y').format(data.startDate!),
                      style: AppTypography.heading(
                        fontSize: 20,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            // In [year] alone pill
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOut,
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Every single day was worth it 💕',
                  style: AppTypography.body(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
