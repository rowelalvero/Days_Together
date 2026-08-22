import 'package:flutter/material.dart';

import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Confirms unlinking from the partner (or cancelling a pending pairing
/// invitation) before calling `CoupleSession.unlinkPartner()` and popping
/// the profile screen. Extracted out of
/// `RelationshipProfileScreen._showUnlinkConfirmation` (per
/// `god-file-decomposition.md` item 5).
class UnlinkConfirmationDialog extends StatelessWidget {
  const UnlinkConfirmationDialog({
    super.key,
    required this.profileContext,
    required this.rp,
    required this.theme,
  });

  /// The settings screen's own context -- kept separate from this widget's
  /// own `build(context)` (the dialog route's context, which unmounts as
  /// soon as `Navigator.pop` closes this dialog) because after unlinking,
  /// the profile screen itself is popped via this context, which must
  /// still be mounted at that point.
  final BuildContext profileContext;
  final CoupleSession rp;
  final LoveStoryTheme theme;

  static void show(BuildContext context, CoupleSession rp, LoveStoryTheme theme) {
    showDialog(
      context: context,
      builder: (dialogContext) => UnlinkConfirmationDialog(
        profileContext: context,
        rp: rp,
        theme: theme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partnerJoined = rp.partnerId != null;

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
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              partnerJoined ? 'Disconnect Relationship' : 'Cancel Invitation',
              style: AppTypography.heading(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              partnerJoined
                  ? 'Are you sure you want to disconnect? This will unlink your profile from your partner and return you to the pairing setup.'
                  : 'Are you sure you want to cancel? This will deactivate your current connection code.',
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
                      'Stay Connected',
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
                      Navigator.pop(context); // close dialog
                      await rp.unlinkPartner();
                      if (profileContext.mounted) {
                        Navigator.pop(profileContext); // exit profile screen
                      }
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
                      partnerJoined ? 'Disconnect' : 'Cancel Code',
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
