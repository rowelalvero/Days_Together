import 'package:flutter/material.dart';
import 'package:days_together/features/scrapbook/presentation/widgets/color_picker_dialog.dart';
import 'package:days_together/features/scrapbook/presentation/widgets/noteit_color_swatch.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

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

  static const _templates = [
    (type: 'color', label: 'Solid', icon: Icons.square_rounded),
    (type: 'grid', label: 'Grid', icon: Icons.grid_4x4_rounded),
    (type: 'dots', label: 'Dots', icon: Icons.blur_on_rounded),
    (type: 'notebook', label: 'Notebook', icon: Icons.menu_book_rounded),
    (type: 'gradient', label: 'Gradient', icon: Icons.gradient_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    // Notebook and gradient paint their own colors.
    final usesColor = _bgType != 'notebook' && _bgType != 'gradient';
    final sectionStyle = AppTypography.caption(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: theme.textColor.withValues(alpha: 0.7),
    ).copyWith(letterSpacing: 1.2);

    return AlertDialog(
      backgroundColor: theme.backgroundColor,
      title: Text(
        'Canvas background',
        style: AppTypography.heading(
          color: theme.textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PATTERN', style: sectionStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _templates)
                ChoiceChip(
                  avatar: Icon(
                    t.icon,
                    size: 18,
                    color: _bgType == t.type
                        ? theme.onAccentColor
                        : theme.textColor.withValues(alpha: 0.8),
                  ),
                  label: Text(t.label),
                  labelStyle: AppTypography.caption(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _bgType == t.type
                        ? theme.onAccentColor
                        : theme.textColor,
                  ),
                  selected: _bgType == t.type,
                  showCheckmark: false,
                  selectedColor: theme.accentColor,
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: _bgType == t.type
                        ? theme.accentColor
                        : theme.textColor.withValues(alpha: 0.25),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => _applyChange(t.type, _bgColor),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('PAPER COLOR', style: sectionStyle),
          const SizedBox(height: 4),
          AnimatedOpacity(
            duration: theme.motion.fast,
            opacity: usesColor ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !usesColor,
              child: Wrap(
                children: [
                  for (final color in widget.paletteColors)
                    NoteitColorSwatch(
                      color: color,
                      theme: theme,
                      size: 30,
                      isSelected: _bgColor.toARGB32() == color.toARGB32(),
                      // Keeps the current pattern; only the solid/grid/dots
                      // templates use the paper color.
                      onTap: () => _applyChange(_bgType, color),
                    ),
                  NoteitCustomColorButton(
                    theme: theme,
                    size: 30,
                    onTap: () async {
                      final pickedColor = await showDialog<Color>(
                        context: context,
                        builder: (ctx2) => ColorPickerDialog(
                          initialColor: _bgColor,
                          theme: theme,
                        ),
                      );
                      if (pickedColor != null) {
                        _applyChange(_bgType, pickedColor);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          if (!usesColor)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'This pattern has its own colors.',
                style: AppTypography.caption(
                  fontSize: 12,
                  color: theme.textColor.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Done',
            style: AppTypography.button(
              color: theme.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
