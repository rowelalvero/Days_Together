import 'package:flutter/material.dart';
import 'package:days_together/screens/wrapped/wrapped_data.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/widgets/wrapped/wrapped_animated_counter.dart';

class WrappedPageCalendar extends StatelessWidget {
  final WrappedData data;
  const WrappedPageCalendar({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final hasEvents = data.calendarEventsThisYear > 0;

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
              child: const Text('📅', style: TextStyle(fontSize: 56)),
            ),
            const SizedBox(height: 20),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              builder: (_, v, c) => Opacity(opacity: v, child: c),
              child: Text(
                'Special Dates',
                style: AppTypography.display(
                  fontSize: 38,
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
                'Moments worth circling on the calendar',
                style: AppTypography.cormorant(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                ).copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 36),
            if (hasEvents) ...[
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFF06292), Color(0xFFF48FB1)],
                ).createShader(b),
                child: WrappedAnimatedCounter(
                  endValue: data.calendarEventsThisYear.toDouble(),
                  duration: const Duration(milliseconds: 1400),
                  style: AppTypography.display(
                    fontSize: 80,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                data.calendarEventsThisYear == 1
                    ? 'special moment in ${data.year}'
                    : 'special moments in ${data.year}',
                style: AppTypography.cormorant(
                  fontSize: 22,
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (data.specialDatesThisYear.isNotEmpty) ...[
                const SizedBox(height: 32),
                ...data.specialDatesThisYear.asMap().entries.map(
                  (e) => _buildEventTile(e.value, e.key),
                ),
              ],
            ] else
              _emptyCalendarState(),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(String title, int index) {
    final icons = ['🎉', '💕', '✈️', '🌟', '🎊'];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 900 + index * 120),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - v)),
        child: Opacity(opacity: v, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Text(
                icons[index % icons.length],
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.body(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyCalendarState() => TweenAnimationBuilder<double>(
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
                'Mark more moments next year.',
                style: AppTypography.heading(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Add anniversaries, trips, and celebrations\nto your shared calendar.',
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
