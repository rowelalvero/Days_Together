import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// One tappable color circle in the scrapbook's palettes (brush, text,
/// highlight, canvas background). A 44x44 touch target around a smaller
/// visual dot; the selection ring uses whichever ink contrasts with the
/// swatch, so selecting white on a dark theme (or black on a light one) is
/// still visible.
class NoteitColorSwatch extends StatelessWidget {
  const NoteitColorSwatch({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.theme,
    this.semanticLabel,
    this.size = 28,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final LoveStoryTheme theme;
  final String? semanticLabel;
  final double size;

  bool get _isNone => color.a == 0;

  @override
  Widget build(BuildContext context) {
    final label =
        semanticLabel ??
        (_isNone
            ? 'No color'
            : 'Color #${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}');
    final fill = _isNone ? theme.textColor.withValues(alpha: 0.08) : color;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: theme.motion.fast,
              curve: theme.motion.standard,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? theme.accentColor
                      : theme.textColor.withValues(alpha: 0.2),
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: theme.accentColor.withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: _isNone
                  ? Icon(
                      Icons.format_color_reset_rounded,
                      size: 14,
                      color: theme.textColor.withValues(alpha: 0.7),
                    )
                  : isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: ThemeContrast.onColor(color),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The rainbow "custom color" button that ends each palette row.
class NoteitCustomColorButton extends StatelessWidget {
  const NoteitCustomColorButton({
    super.key,
    required this.onTap,
    required this.theme,
    this.size = 28,
  });

  final VoidCallback onTap;
  final LoveStoryTheme theme;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Custom color',
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.textColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                gradient: const SweepGradient(
                  colors: [
                    Colors.red,
                    Colors.yellow,
                    Colors.green,
                    Colors.blue,
                    Colors.red,
                  ],
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 16,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared look for the scrapbook's floating sheets (brush and text panels).
BoxDecoration noteitPanelDecoration(LoveStoryTheme theme) => BoxDecoration(
  color: theme.backgroundColor.withValues(alpha: 0.96),
  borderRadius: BorderRadius.circular(theme.radii.md + 4),
  border: Border.all(color: theme.textColor.withValues(alpha: 0.12)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ],
);

/// Small uppercase row label used inside the scrapbook panels.
class NoteitPanelLabel extends StatelessWidget {
  const NoteitPanelLabel(this.text, {super.key, required this.theme});

  final String text;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: AppTypography.caption(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: theme.textColor.withValues(alpha: 0.7),
        ).copyWith(letterSpacing: 1.2),
      ),
    );
  }
}
