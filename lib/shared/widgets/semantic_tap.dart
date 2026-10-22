import 'package:flutter/material.dart';

/// A custom-drawn tap target that assistive technology treats as a real
/// control: one node with [label], a button role (or checkbox, when
/// [checked] is set), optional selected state, disabled when [onTap] is
/// null, and the tap action wired to [onTap].
///
/// Use it where the design calls for a bespoke shape (a circle, a pill, an
/// avatar) instead of an IconButton. The child's own semantics are replaced
/// by [label], so put any visible text into the label too.
///
/// [minTapTarget] grows the hit area around the child without changing how
/// it looks: 48 for the Android/Material guideline, 24 for WCAG 2.2's
/// minimum where the surrounding layout can't spare more.
class SemanticTap extends StatelessWidget {
  const SemanticTap({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.selected,
    this.checked,
    this.minTapTarget = 0,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final bool? selected;
  final bool? checked;
  final double minTapTarget;

  @override
  Widget build(BuildContext context) {
    Widget target = child;
    if (minTapTarget > 0) {
      target = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minTapTarget,
          minHeight: minTapTarget,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      );
    }
    return Semantics(
      container: true,
      button: checked == null,
      checked: checked,
      selected: selected,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        child: target,
      ),
    );
  }
}
