import 'package:flutter/material.dart';
import 'package:days_together/features/scrapbook/presentation/widgets/color_picker_dialog.dart';
import 'package:days_together/features/scrapbook/presentation/widgets/noteit_color_swatch.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// Properties sheet for brush/drawing configurations (stroke size slider
/// with a live preview dot, shape picker, and color palette).
class NoteitBrushPropertiesPanel extends StatelessWidget {
  final LoveStoryTheme theme;
  final String activeMode;
  final double strokeWidth;
  final String activeShape;
  final Color brushColor;
  final List<Color> paletteColors;
  final ValueChanged<double> onStrokeWidthChanged;
  final ValueChanged<String> onShapeChanged;
  final ValueChanged<Color> onBrushColorChanged;

  const NoteitBrushPropertiesPanel({
    super.key,
    required this.theme,
    required this.activeMode,
    required this.strokeWidth,
    required this.activeShape,
    required this.brushColor,
    required this.paletteColors,
    required this.onStrokeWidthChanged,
    required this.onShapeChanged,
    required this.onBrushColorChanged,
  });

  static const _shapes = [
    (value: 'rectangle', icon: Icons.crop_square_rounded, label: 'Rectangle'),
    (value: 'oval', icon: Icons.circle_outlined, label: 'Oval'),
    (value: 'line', icon: Icons.horizontal_rule_rounded, label: 'Line'),
    (value: 'arrow', icon: Icons.north_east_rounded, label: 'Arrow'),
  ];

  @override
  Widget build(BuildContext context) {
    final isEraser = activeMode == 'eraser';
    // Preview matches what the eraser/marker actually paint with.
    final previewSize =
        (isEraser
                ? strokeWidth * 3
                : activeMode == 'marker'
                ? strokeWidth * 2.5
                : strokeWidth)
            .clamp(2.0, 28.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: noteitPanelDecoration(theme),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (activeMode == 'shapes')
            Row(
              children: [
                NoteitPanelLabel('Shape', theme: theme),
                for (final shape in _shapes)
                  _ShapeChoice(
                    icon: shape.icon,
                    label: shape.label,
                    isSelected: activeShape == shape.value,
                    theme: theme,
                    onTap: () => onShapeChanged(shape.value),
                  ),
              ],
            ),
          Row(
            children: [
              NoteitPanelLabel('Size', theme: theme),
              Expanded(
                child: Slider(
                  value: strokeWidth,
                  min: 1.0,
                  max: 20.0,
                  label: strokeWidth.round().toString(),
                  semanticFormatterCallback: (v) => 'Brush size ${v.round()}',
                  activeColor: theme.accentColor,
                  inactiveColor: theme.textColor.withValues(alpha: 0.15),
                  onChanged: onStrokeWidthChanged,
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: Container(
                    width: previewSize,
                    height: previewSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isEraser
                          ? Colors.transparent
                          : brushColor.withValues(
                              alpha: activeMode == 'marker' ? 0.35 : 1,
                            ),
                      border: Border.all(
                        color: theme.textColor.withValues(alpha: 0.4),
                        width: isEraser ? 1.5 : 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!isEraser)
            Row(
              children: [
                NoteitPanelLabel('Color', theme: theme),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final color in paletteColors)
                          NoteitColorSwatch(
                            color: color,
                            theme: theme,
                            isSelected:
                                brushColor.toARGB32() == color.toARGB32(),
                            onTap: () => onBrushColorChanged(color),
                          ),
                        NoteitCustomColorButton(
                          theme: theme,
                          onTap: () async {
                            final pickedColor = await showDialog<Color>(
                              context: context,
                              builder: (ctx2) => ColorPickerDialog(
                                initialColor: brushColor,
                                theme: theme,
                              ),
                            );
                            if (pickedColor != null) {
                              onBrushColorChanged(pickedColor);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 6),
              child: Text(
                'Drag over strokes to erase them.',
                style: AppTypography.caption(
                  fontSize: 12,
                  color: theme.textColor.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShapeChoice extends StatelessWidget {
  const _ShapeChoice({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final LoveStoryTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.accentColor.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(theme.radii.sm + 2),
                  border: Border.all(
                    color: isSelected
                        ? theme.accentColor
                        : theme.textColor.withValues(alpha: 0.15),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? theme.accentColor
                      : theme.textColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
