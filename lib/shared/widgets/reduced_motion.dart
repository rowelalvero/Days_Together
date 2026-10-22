import 'package:flutter/widgets.dart';

/// Whether the user asked the OS to reduce motion (iOS "Reduce Motion",
/// Android "Remove animations"). Registers a MediaQuery dependency, so a
/// widget reading it in build/didChangeDependencies follows the setting
/// live.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Decorative animation that respects [prefersReducedMotion].
extension ReducedMotionAnimation on AnimationController {
  /// Loops like [repeat] -- unless reduced motion is on, in which case the
  /// loop stops on a still frame at [restValue]. Call it from
  /// `didChangeDependencies` (not `initState`) so it reacts when the
  /// setting changes while the screen is open.
  void repeatUnlessReducedMotion(
    BuildContext context, {
    bool reverse = false,
    double restValue = 0.5,
  }) {
    if (prefersReducedMotion(context)) {
      if (isAnimating) stop();
      value = restValue;
    } else if (!isAnimating) {
      repeat(reverse: reverse);
    }
  }

  /// Plays a one-shot flourish ([forward]) -- unless reduced motion is on,
  /// in which case it jumps straight to the end, so "has it played?" checks
  /// on [value] still hold but nothing moves.
  void playUnlessReducedMotion(BuildContext context, {double? from}) {
    if (prefersReducedMotion(context)) {
      value = upperBound;
    } else {
      forward(from: from);
    }
  }
}
