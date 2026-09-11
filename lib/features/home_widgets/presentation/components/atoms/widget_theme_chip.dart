import 'package:flutter/material.dart';
import 'package:days_together/shared/models/app_settings.dart';
import 'package:days_together/app/theme/theme_manager.dart';

class WidgetThemeChip extends StatelessWidget {
  final ThemeType themeType;
  final bool isSelected;
  final VoidCallback onSelected;

  const WidgetThemeChip({
    super.key,
    required this.themeType,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.getTheme(themeType);

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.accentColor : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
          gradient: LinearGradient(
            colors: [
              theme.primaryColor.withValues(alpha: isSelected ? 0.9 : 0.4),
              theme.secondaryColor.withValues(alpha: isSelected ? 0.9 : 0.4),
            ],
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.accentColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.accentColor,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              theme.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
