import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The "are you sure you want to log out" confirmation on [SettingsTab].
/// Extracted from its `_showLogoutConfirmation` (Migration audit item 6)
/// -- the actual `logout()` call stays on the tab, since it's a state
/// mutation, not rendering.
///
/// Shown directly as a `showDialog` builder, matching this app's other
/// dialogs -- no `.show()` static helper.
class LogoutConfirmationDialog extends StatelessWidget {
  const LogoutConfirmationDialog({
    super.key,
    required this.theme,
    required this.onConfirm,
  });

  final LoveStoryTheme theme;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: theme.primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24),
          const SizedBox(width: 12),
          Text(
            'Log Out',
            style: AppTypography.title(
              color: theme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Text(
        'This will erase all your local data including memories, settings, and theme preferences.\n\nAre you sure?',
        style: AppTypography.body(
          color: theme.textColor.withValues(alpha: 0.7),
          fontSize: 14,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Keep Logged In',
            style: AppTypography.body(
              color: theme.textColor.withValues(alpha: 0.54),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // close dialog
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Log Out',
            style: AppTypography.body(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
