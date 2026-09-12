import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "I have copied and saved my recovery code" checkbox row on
/// [CreateCoupleCodeScreen]. Extracted from its inline `build()`
/// (Migration audit item 6).
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
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: theme.accentColor,
        ),
        Expanded(
          child: Text(
            'I have copied and saved my recovery code.',
            style: AppTypography.body(color: theme.textColor, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
