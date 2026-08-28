import 'package:flutter/material.dart';
import 'package:days_together/features/scrapbook/presentation/color_picker_dialog.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Properties sheet for brush/drawing configurations (stroke width slider,
/// shape type dropdown, and color palette picker).
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row with Stroke Width and Shape selection
          Row(
            children: [
              Text(
                'Width:',
                style: AppTypography.body(color: theme.textColor, fontSize: 13),
              ),
              Expanded(
                child: Slider(
                  value: strokeWidth,
                  min: 1.0,
                  max: 20.0,
                  activeColor: theme.accentColor,
                  inactiveColor: theme.textColor.withValues(alpha: 0.1),
                  onChanged: onStrokeWidthChanged,
                ),
              ),
              if (activeMode == 'shapes') ...[
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: activeShape,
                  dropdownColor: theme.backgroundColor,
                  style: AppTypography.body(color: theme.textColor),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'rectangle', child: Text('Rectangle')),
                    DropdownMenuItem(value: 'oval', child: Text('Oval')),
                    DropdownMenuItem(value: 'line', child: Text('Line')),
                    DropdownMenuItem(value: 'arrow', child: Text('Arrow')),
                  ],
                  onChanged: (val) {
                    if (val != null) onShapeChanged(val);
                  },
                ),
              ],
            ],
          ),

          // Row with color palette picker
          if (activeMode != 'eraser') ...[
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: paletteColors.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == paletteColors.length) {
                    return GestureDetector(
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
                      child: Container(
                        width: 32,
                        height: 32,
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
                        child: Icon(
                          Icons.add_rounded,
                          color: theme.textColor,
                          size: 18,
                        ),
                      ),
                    );
                  }

                  final color = paletteColors[i];
                  final isSelected = brushColor.toARGB32() == color.toARGB32();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onBrushColorChanged(color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? theme.textColor : Colors.transparent,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
