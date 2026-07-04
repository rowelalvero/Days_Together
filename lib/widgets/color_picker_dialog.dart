import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final LoveStoryTheme theme;

  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.theme,
  });

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;
  late double _hue;
  late double _saturation;
  late double _value;

  final List<Color> _presetColors = [
    const Color(0xFFFF4D6D), // pink
    const Color(0xFFFF85A1), // light pink
    const Color(0xFFFFB3C1), // soft pink
    const Color(0xFF00B4D8), // cyan
    const Color(0xFF9D4EDD), // purple
    const Color(0xFFD4AF37), // gold
    const Color(0xFFE63946), // bright red
    const Color(0xFF2A9D8F), // teal
    const Color(0xFFF4A261), // sandy orange
    Colors.white,
    Colors.grey,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _updateHsvFromColor(_selectedColor);
  }

  void _updateHsvFromColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  void _updateColorFromHsv() {
    setState(() {
      _selectedColor = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.theme.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Color',
              style: AppTypography.sectionHeader(
                color: widget.theme.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Color preview and preset palette
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.theme.textColor.withValues(alpha: 0.2), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Hex: #${_selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}',
                    style: AppTypography.bodyLarge(
                      color: widget.theme.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            Text(
              'Presets',
              style: AppTypography.caption(
                color: widget.theme.textColor.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetColors.map((color) {
                final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                      _updateHsvFromColor(color);
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? widget.theme.accentColor : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            
            Text(
              'Custom Color',
              style: AppTypography.caption(
                color: widget.theme.textColor.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            
            // Hue Slider
            Row(
              children: [
                SizedBox(width: 45, child: Text('Hue', style: AppTypography.body(color: widget.theme.textColor, fontSize: 13))),
                Expanded(
                  child: Slider(
                    value: _hue,
                    min: 0.0,
                    max: 360.0,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) {
                      setState(() {
                        _hue = val;
                        _updateColorFromHsv();
                      });
                    },
                  ),
                ),
              ],
            ),
            
            // Saturation Slider
            Row(
              children: [
                SizedBox(width: 45, child: Text('Sat', style: AppTypography.body(color: widget.theme.textColor, fontSize: 13))),
                Expanded(
                  child: Slider(
                    value: _saturation,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Colors.redAccent,
                    onChanged: (val) {
                      setState(() {
                        _saturation = val;
                        _updateColorFromHsv();
                      });
                    },
                  ),
                ),
              ],
            ),
            
            // Value Slider
            Row(
              children: [
                SizedBox(width: 45, child: Text('Value', style: AppTypography.body(color: widget.theme.textColor, fontSize: 13))),
                Expanded(
                  child: Slider(
                    value: _value,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) {
                      setState(() {
                        _value = val;
                        _updateColorFromHsv();
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: AppTypography.button(color: widget.theme.textColor.withValues(alpha: 0.6)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selectedColor),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.theme.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Select',
                    style: AppTypography.button(color: Colors.white),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
