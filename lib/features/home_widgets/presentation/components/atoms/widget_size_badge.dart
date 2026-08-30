import 'package:flutter/material.dart';

class WidgetSizeBadge extends StatelessWidget {
  final String sizeLabel;
  final bool isSelected;
  final VoidCallback onTap;

  const WidgetSizeBadge({
    super.key,
    required this.sizeLabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? const Color(0xFFE8477E).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: isSelected ? const Color(0xFFE8477E) : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          sizeLabel,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.65),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
