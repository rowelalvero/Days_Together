import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The close/title/save row at the top of [EditItemDialog]. Extracted from
/// its `_buildAppBar` (Migration audit item 6).
class EditItemAppBar extends StatelessWidget {
  const EditItemAppBar({
    super.key,
    required this.theme,
    required this.isSaving,
    required this.onSave,
  });

  final LoveStoryTheme theme;
  final bool isSaving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, color: theme.textColor, size: 28),
          ),
          Text(
            'Edit Memory',
            style: AppTypography.heading(
              color: theme.textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.check_rounded, color: theme.accentColor, size: 28),
          ),
        ],
      ),
    );
  }
}
