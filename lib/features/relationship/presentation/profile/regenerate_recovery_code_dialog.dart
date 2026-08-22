import 'package:flutter/material.dart';

import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/features/relationship/presentation/profile/new_recovery_code_dialog.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/shared/safe_loading_dialog.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Warns that regenerating the recovery code invalidates the old one, then
/// (on confirm) regenerates it and opens [NewRecoveryCodeDialog] to show
/// the new code once. Extracted out of
/// `RelationshipProfileScreen._showRegenerateRecoveryCodeDialog` (per
/// `god-file-decomposition.md` item 5).
class RegenerateRecoveryCodeDialog extends StatelessWidget {
  const RegenerateRecoveryCodeDialog({
    super.key,
    required this.profileContext,
    required this.rp,
    required this.theme,
  });

  /// The settings screen's own context -- kept separate from this widget's
  /// own `build(context)` (the dialog route's context, which unmounts the
  /// instant `Navigator.pop` closes this dialog) because the regenerate
  /// button's async work continues *after* this dialog closes and needs a
  /// context that is still mounted at that point.
  final BuildContext profileContext;
  final CoupleSession rp;
  final LoveStoryTheme theme;

  static void show(BuildContext context, CoupleSession rp, LoveStoryTheme theme) {
    showDialog(
      context: context,
      builder: (dialogContext) => RegenerateRecoveryCodeDialog(
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
                color: theme.accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.security_rounded,
                color: theme.accentColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Regenerate Recovery Code',
              style: AppTypography.heading(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Regenerating your recovery code will permanently invalidate all previously issued recovery codes. You will only be shown the new code once.',
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
                      Navigator.pop(context); // Close warning dialog

                      final success = await SafeLoadingDialog.run<bool>(
                        context: profileContext,
                        future: () async {
                          await rp.regenerateRecoveryCode();
                          return true;
                        },
                        timeoutSeconds: 15,
                        loadingMessage: 'Regenerating code...',
                      );

                      if (success == true && profileContext.mounted) {
                        NewRecoveryCodeDialog.show(profileContext, rp, theme);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Regenerate',
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
