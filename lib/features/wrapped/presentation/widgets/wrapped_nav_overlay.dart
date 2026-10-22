import 'package:flutter/material.dart';

/// Invisible overlay handling tap-left (previous) and tap-right (next)
/// page navigation, plus a skip button at the top-right.
///
/// The tap zones are a pointer shortcut only and are excluded from
/// semantics: exposed, they were two unlabeled screen-sized "buttons" laid
/// over the story. Screen readers page through [WrappedProgressBar]'s
/// Next/Previous custom actions instead.
class WrappedNavOverlay extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;
  final bool isLastPage;

  const WrappedNavOverlay({
    super.key,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    this.isLastPage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Left tap zone — previous page
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.3,
          child: ExcludeSemantics(
            child: GestureDetector(
              onTap: onPrevious,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        // Right tap zone — next page
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.7,
          child: ExcludeSemantics(
            child: GestureDetector(
              onTap: onNext,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        // Skip / close button: a labeled button with a 48dp tap target
        // around the visible pill.
        if (!isLastPage)
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            right: 20,
            child: MergeSemantics(
              child: Semantics(
                button: true,
                child: GestureDetector(
                  onTap: onSkip,
                  behavior: HitTestBehavior.opaque,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
