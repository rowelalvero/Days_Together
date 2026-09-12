import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/models/timeline_model.dart';

/// The memory picker on [AILoveLetterScreen]. Extracted from its
/// `_buildMemoryDropdown` method (Migration audit item 6) -- the
/// default-to-first-memory selection logic stays on the screen's State,
/// matching `_generateLetter`'s own identical fallback.
class MemoryDropdown extends StatelessWidget {
  const MemoryDropdown({
    super.key,
    required this.memories,
    required this.selectedMemoryId,
    required this.onChanged,
    required this.theme,
  });

  final List<TimelineItemData> memories;
  final String? selectedMemoryId;
  final ValueChanged<String?> onChanged;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedMemoryId,
          dropdownColor: theme.primaryColor,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: theme.textColor),
          items: memories.map((m) {
            return DropdownMenuItem<String>(
              value: m.id,
              child: Row(
                children: [
                  Text(m.mood, style: AppTypography.body(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      m.title,
                      style: AppTypography.body(color: theme.textColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
