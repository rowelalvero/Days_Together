import 'package:flutter/material.dart';

import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/shared/safe_loading_dialog.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Confirms permanent account deletion before calling
/// `CoupleSession.deleteAccount()`. Extracted out of
/// `RelationshipProfileScreen._showDeleteAccountConfirmation` (per
/// `god-file-decomposition.md` item 5).
class DeleteAccountConfirmationDialog extends StatelessWidget {
  const DeleteAccountConfirmationDialog({
    super.key,
    required this.profileContext,
    required this.rp,
    required this.theme,
  });

  /// The settings screen's own context -- kept separate from this widget's
  /// own `build(context)` (the dialog route's context, which unmounts as
  /// soon as `Navigator.pop` closes this dialog) because the delete
  /// button's `SafeLoadingDialog` needs a context that is still mounted
  /// after this dialog has already been popped.
  final BuildContext profileContext;
  final CoupleSession rp;
  final LoveStoryTheme theme;

  static void show(BuildContext context, CoupleSession rp, LoveStoryTheme theme) {
    showDialog(
      context: context,
      builder: (dialogContext) => DeleteAccountConfirmationDialog(
        profileContext: context,
        rp: rp,
        theme: theme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        borderRadius: 28,
        padding: const EdgeInsets.all(28),
        opacity: theme.isDark ? 0.1 : 0.85,
        gradient: theme.isDark
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.85),
                ],
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.redAccent,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Delete Account',
              style: AppTypography.heading(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Are you absolutely sure you want to delete your account? This action is permanent. All your personal data will be erased immediately. If you are paired, your partner will be returned to a single state and all shared memories and notes will be deleted forever.',
              style: AppTypography.body(
                fontSize: 14,
                color: theme.textColor.withValues(alpha: 0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: AppTypography.body(
                        color: theme.textColor.withValues(alpha: 0.4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context); // Close confirmation dialog

                      // No explicit navigation after this: deleteAccount()
                      // ends in logout(wipeAll: true), which clears
                      // CoupleSession's identity fields -- the
                      // router's single redirect (app_router.dart) picks
                      // that up via refreshListenable and recomputes the
                      // correct destination, replacing the old
                      // popUntil(isFirst)-to-root strategy (ADR-007
                      // found this used a different "return to root"
                      // mechanism than settings_tab.dart's logout did).
                      await SafeLoadingDialog.run<bool>(
                        context: profileContext,
                        future: () async {
                          await rp.deleteAccount();
                          return true;
                        },
                        timeoutSeconds: 20,
                        loadingMessage: 'Deleting account...',
                        indicatorColor: Colors.redAccent,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Delete',
                      style: AppTypography.body(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
