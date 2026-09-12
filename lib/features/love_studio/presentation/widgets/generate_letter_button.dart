import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "Write Love Letter" button on [AILoveLetterScreen]. Extracted from
/// its `_buildActionButtons` method (Migration audit item 6).
class GenerateLetterButton extends StatelessWidget {
  const GenerateLetterButton({
    super.key,
    required this.onPressed,
    required this.theme,
  });

  final VoidCallback onPressed;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.auto_awesome, color: Colors.white),
          label: Text(
            'Write Love Letter',
            style: AppTypography.button(color: Colors.white, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
