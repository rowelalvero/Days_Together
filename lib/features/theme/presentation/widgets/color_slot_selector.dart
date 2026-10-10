import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/models/app_settings.dart';

class _SlotData {
  final String key;
  final String label;
  final int colorValue;
  const _SlotData(this.key, this.label, this.colorValue);
}

/// The Primary/Secondary/Background/Accent chip row in the custom theme
/// designer, choosing which slot the color palette below edits. Extracted
/// from `_CustomThemeDesignerState._buildColorSlots` (Migration audit item
/// 6).
class ColorSlotSelector extends StatelessWidget {
  const ColorSlotSelector({
    super.key,
    required this.settings,
    required this.theme,
    required this.activeSlot,
    required this.onSlotSelected,
  });

  final AppSettings settings;
  final LoveStoryTheme theme;
  final String activeSlot;
  final ValueChanged<String> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    final slots = [
      _SlotData('primary', 'Primary', settings.customPrimaryColor),
      _SlotData('secondary', 'Secondary', settings.customSecondaryColor),
      _SlotData('background', 'Background', settings.customBackgroundColor),
      _SlotData('accent', 'Accent', settings.customAccentColor),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: slots.map((slot) {
        final isActive = activeSlot == slot.key;
        return Semantics(
          button: true,
          selected: isActive,
          child: InkWell(
            onTap: () => onSlotSelected(slot.key),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.accentColor.withValues(alpha: 0.2)
                    : theme.textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? theme.accentColor
                      : theme.textColor.withValues(alpha: 0.1),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Color(slot.colorValue),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.textColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    slot.label,
                    style: AppTypography.caption(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? theme.accentColor
                          : theme.textColor.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
