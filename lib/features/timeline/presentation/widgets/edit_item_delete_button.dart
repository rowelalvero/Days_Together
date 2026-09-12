import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "Delete Memory" button in [EditItemDialog], including its confirm
/// dialog. Extracted from its `_buildDeleteButton` (Migration audit item
/// 6) -- [onConfirmedDelete] performs the actual deletion and navigation,
/// which needs `ref`/`context.mounted` on the dialog's State.
class EditItemDeleteButton extends StatelessWidget {
  const EditItemDeleteButton({
    super.key,
    required this.theme,
    required this.onConfirmedDelete,
  });

  final LoveStoryTheme theme;
  final VoidCallback onConfirmedDelete;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: theme.secondaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'Delete Memory?',
                style: AppTypography.bodyLarge(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Cancel',
                    style: AppTypography.button(
                      color: theme.textColor.withValues(alpha: 0.54),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    'Delete',
                    style: AppTypography.button(
                      color: theme.accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            onConfirmedDelete();
          }
        },
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.redAccent,
          size: 20,
        ),
        label: Text(
          'Delete Memory',
          style: AppTypography.bodyLarge(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
