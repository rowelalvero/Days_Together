import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "I've saved my recovery code" confirmation on
/// [CreateCoupleCodeScreen]. The whole row is the tap target, not just the
/// 18px box.
class RecoverySavedCheckbox extends StatelessWidget {
  const RecoverySavedCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(theme.radii.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: theme.accentColor,
                checkColor: theme.onAccentColor,
                side: BorderSide(
                  color: theme.textColor.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              Expanded(
                child: Text(
                  'I\'ve saved my recovery code somewhere safe.',
                  style: AppTypography.body(
                    color: theme.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
