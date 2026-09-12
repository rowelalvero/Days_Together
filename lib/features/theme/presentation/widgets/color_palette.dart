import 'package:flutter/material.dart';

/// The curated romantic color swatches in the custom theme designer.
/// Extracted from `_CustomThemeDesignerState._buildColorPalette` (Migration
/// audit item 6), along with the palette's color list itself.
class ColorPalette extends StatelessWidget {
  const ColorPalette({
    super.key,
    required this.activeColor,
    required this.onColorSelected,
  });

  final int activeColor;
  final ValueChanged<int> onColorSelected;

  static const List<int> colors = [
    0xFFFF4D6D,
    0xFFC9184A,
    0xFFFF85A1,
    0xFFFFC4D6,
    0xFFFF6B9D,
    0xFF7B2CBF,
    0xFF9D4EDD,
    0xFFE0AAFF,
    0xFFBB86FC,
    0xFF6200EA,
    0xFF00B4D8,
    0xFF0077B6,
    0xFFADE8F4,
    0xFF48CAE4,
    0xFF03045E,
    0xFF2D6A4F,
    0xFF52B788,
    0xFF95D5B2,
    0xFFFFB703,
    0xFFE8477E,
    0xFF10122B,
    0xFF1A1B41,
    0xFF0A0B1A,
    0xFF2C003E,
    0xFF590D22,
    0xFFFFF0F5,
    0xFFFFE4EC,
    0xFFFFF8FA,
    0xFFF8EDEB,
    0xFFE8E0D8,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((colorValue) {
        final isSelected = activeColor == colorValue;
        return GestureDetector(
          onTap: () => onColorSelected(colorValue),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Color(colorValue),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: isSelected ? 3 : 0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Color(colorValue).withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: isSelected
                ? const Center(
                    child: Icon(Icons.check, color: Colors.white, size: 18),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}
