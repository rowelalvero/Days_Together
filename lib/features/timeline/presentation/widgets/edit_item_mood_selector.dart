import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The 5-emoji mood picker in [EditItemDialog]. Extracted from its
/// `_buildMoodSelector` (Migration audit item 6).
class EditItemMoodSelector extends StatelessWidget {
  const EditItemMoodSelector({
    super.key,
    required this.theme,
    required this.selectedMood,
    required this.onMoodSelected,
  });

  static const moods = ['😍', '🥳', '😂', '😢', '🏠'];

  final LoveStoryTheme theme;
  final String selectedMood;
  final ValueChanged<String> onMoodSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mood',
          style: AppTypography.bodyLarge(
            color: theme.textColor.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ).copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: moods.map((m) {
            final isSelected = selectedMood == m;
            return GestureDetector(
              onTap: () => onMoodSelected(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? theme.accentColor : Colors.white10,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(m, style: AppTypography.body(fontSize: 24)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
