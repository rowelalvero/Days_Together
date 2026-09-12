import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/love_studio/domain/entities/time_capsule_model.dart';

/// The opened-capsule dialog on [TimeCapsuleScreen]: creation date and the
/// sealed message. Extracted from the screen's `_showCapsuleDetailDialog`
/// (Migration audit item 6) -- the `openCapsule` side effect that dialog
/// triggered before showing stays on the screen, since it's a state
/// mutation, not rendering.
///
/// Shown directly as a `showDialog` builder, matching this app's other
/// dialogs -- no `.show()` static helper.
class CapsuleDetailDialog extends StatelessWidget {
  const CapsuleDetailDialog({
    super.key,
    required this.capsule,
    required this.theme,
  });

  final TimeCapsule capsule;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: theme.primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.drafts_rounded, color: Colors.pinkAccent),
          const SizedBox(width: 12),
          Text(
            'Opened Capsule',
            style: AppTypography.title(color: theme.textColor),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Created: ${DateFormat('MMMM dd, yyyy').format(capsule.createdAt)}',
              style: AppTypography.bodyMedium(
                color: theme.textColor.withValues(alpha: 0.54),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              capsule.message,
              style: AppTypography.lora(
                fontSize: 16,
                height: 1.5,
                color: theme.textColor,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: AppTypography.button(color: theme.accentColor),
          ),
        ),
      ],
    );
  }
}
