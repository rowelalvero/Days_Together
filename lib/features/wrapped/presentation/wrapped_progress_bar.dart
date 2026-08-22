import 'package:flutter/material.dart';

/// Story-style progress bar at the top of each Wrapped page.
class WrappedProgressBar extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final Color color;

  const WrappedProgressBar({
    super.key,
    required this.totalPages,
    required this.currentPage,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalPages, (i) {
        final isCompleted = i < currentPage;
        final isActive = i == currentPage;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: color.withValues(alpha: isCompleted
                  ? 0.9
                  : isActive
                      ? 0.6
                      : 0.25),
            ),
            child: isActive
                ? TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    builder: (context, value, _) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: color.withValues(alpha: 0.9),
                          ),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      }),
    );
  }
}
