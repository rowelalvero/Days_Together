import 'package:flutter/material.dart';
import 'package:days_together/features/scrapbook/presentation/color_picker_dialog.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Modal dialog allowing the user to select canvas background templates (solid,
/// grid, dot grid, notebook, gradient) and custom solid colors.
class NoteitBackgroundDialog extends StatefulWidget {
  final LoveStoryTheme theme;
  final String initialBgType;
  final Color initialBgColor;
  final List<Color> paletteColors;
  final void Function(String bgType, Color bgColor) onBackgroundChanged;

  const NoteitBackgroundDialog({
    super.key,
    required this.theme,
    required this.initialBgType,
    required this.initialBgColor,
    required this.paletteColors,
    required this.onBackgroundChanged,
  });

  @override
  State<NoteitBackgroundDialog> createState() => _NoteitBackgroundDialogState();
}

class _NoteitBackgroundDialogState extends State<NoteitBackgroundDialog> {
  late String _bgType;
  late Color _bgColor;

  @override
  void initState() {
    super.initState();
    _bgType = widget.initialBgType;
    _bgColor = widget.initialBgColor;
  }

  void _applyChange(String bgType, Color bgColor) {
    setState(() {
      _bgType = bgType;
      _bgColor = bgColor;
    });
    widget.onBackgroundChanged(_bgType, _bgColor);
  }

  Widget _buildBgOptionButton(String type, String label, Color previewColor) {
    final isSelected = _bgType == type;
    final theme = widget.theme;

    return OutlinedButton(
      onPressed: () => _applyChange(type, _bgColor),
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? theme.accentColor : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : theme.textColor,
        side: BorderSide(
          color: isSelected ? theme.accentColor : theme.textColor.withValues(alpha: 0.2),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return AlertDialog(
      backgroundColor: theme.backgroundColor,
      title: Text(
        'Canvas Settings',
        style: AppTypography.heading(
          color: theme.textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Background Template:',
            style: AppTypography.body(
              color: theme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBgOptionButton('color', 'Solid color', Colors.white),
              _buildBgOptionButton('grid', 'Grid Lines', Colors.white),
              _buildBgOptionButton('dots', 'Dot Grid', Colors.white),
              _buildBgOptionButton('notebook', 'Notebook', const Color(0xFFF9F9FB)),
              _buildBgOptionButton('gradient', 'Gradient', Colors.white),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Solid Color Picker:',
            style: AppTypography.body(
              color: theme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...widget.paletteColors.map((color) {
                final isSelectedColor = _bgType == 'color' && _bgColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => _applyChange('color', color),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelectedColor ? theme.textColor : Colors.grey.withValues(alpha: 0.3),
                        width: isSelectedColor ? 2.5 : 1.0,
                      ),
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: () async {
                  final pickedColor = await showDialog<Color>(
                    context: context,
                    builder: (ctx2) => ColorPickerDialog(
                      initialColor: _bgColor,
                      theme: theme,
                    ),
                  );
                  if (pickedColor != null) {
                    _applyChange('color', pickedColor);
                  }
                },
                child: Container(
                  width: 30,
                  height: 30,
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
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Done',
            style: AppTypography.button(color: theme.accentColor),
          ),
        ),
      ],
    );
  }
}
