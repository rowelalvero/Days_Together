import 'package:flutter/material.dart';

/// Reusable count-up animated number display for Wrapped pages.
class WrappedAnimatedCounter extends StatelessWidget {
  final double endValue;
  final Duration duration;
  final TextStyle style;
  final String Function(int value)? formatter;

  const WrappedAnimatedCounter({
    super.key,
    required this.endValue,
    required this.style,
    this.duration = const Duration(milliseconds: 1600),
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: endValue),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final display = formatter != null
            ? formatter!(value.toInt())
            : value.toInt().toString();
        return Text(display, style: style);
      },
    );
  }
}
