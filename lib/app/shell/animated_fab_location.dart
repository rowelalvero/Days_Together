import 'package:flutter/material.dart';

/// A [FloatingActionButtonLocation] pinned to the bottom-right corner at a
/// caller-supplied offset from the bottom, so [LoveStoryScreen] can slide
/// its FAB up when the floating nav bar's scrubber row expands. Moved out
/// of the screen file into its own file as part of Migration audit item 6
/// -- it was already a proper class, just living inline in the screen.
class AnimatedFabLocation extends FloatingActionButtonLocation {
  final double bottomOffset;
  const AnimatedFabLocation(this.bottomOffset);

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX =
        scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.minInsets.right -
        scaffoldGeometry.floatingActionButtonSize.width -
        16.0;
    final double fabY =
        scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        bottomOffset;
    return Offset(fabX, fabY);
  }
}
