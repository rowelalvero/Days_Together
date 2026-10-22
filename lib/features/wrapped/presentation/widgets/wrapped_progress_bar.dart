import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

/// Story-style progress bar at the top of each Wrapped page.
///
/// It is also the story's screen-reader control: a single "Page n of N"
/// node, announced as the page changes, carrying "Next page" / "Previous
/// page" custom actions (TalkBack's actions menu, VoiceOver's rotor). The
/// sighted tap zones in [WrappedNavOverlay] are hidden from screen readers,
/// so these actions are how a screen-reader user moves through the story.
class WrappedProgressBar extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final Color color;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const WrappedProgressBar({
    super.key,
    required this.totalPages,
    required this.currentPage,
    this.color = Colors.white,
    this.onNext,
    this.onPrevious,
  });

  static const nextPageAction = CustomSemanticsAction(label: 'Next page');
  static const previousPageAction = CustomSemanticsAction(
    label: 'Previous page',
  );

  @override
  Widget build(BuildContext context) {
    final next = onNext;
    final previous = onPrevious;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Page ${currentPage + 1} of $totalPages',
      customSemanticsActions: {
        if (next != null && currentPage < totalPages - 1) nextPageAction: next,
        if (previous != null && currentPage > 0) previousPageAction: previous,
      },
      child: Row(
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
                color: color.withValues(
                  alpha: isCompleted
                      ? 0.9
                      : isActive
                      ? 0.6
                      : 0.25,
                ),
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
      ),
    );
  }
}
