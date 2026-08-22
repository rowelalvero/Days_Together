import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Shows the freshly-regenerated recovery code once, requiring the user to
/// check a confirmation box before continuing (which clears the code from
/// state -- it is never shown again). Extracted out of
/// `RelationshipProfileScreen._showNewRecoveryCodeDialog` (per
/// `god-file-decomposition.md` item 5: this file is not a real
/// architectural problem, but its dialog bodies were verbosely inlined
/// rather than extracted -- opportunistic, low-priority readability work).
class NewRecoveryCodeDialog extends StatefulWidget {
  const NewRecoveryCodeDialog({super.key, required this.rp, required this.theme});

  final CoupleSession rp;
  final LoveStoryTheme theme;

  static void show(BuildContext context, CoupleSession rp, LoveStoryTheme theme) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force them to save and check the box
      builder: (context) => NewRecoveryCodeDialog(rp: rp, theme: theme),
    );
  }

  @override
  State<NewRecoveryCodeDialog> createState() => _NewRecoveryCodeDialogState();
}

class _NewRecoveryCodeDialogState extends State<NewRecoveryCodeDialog> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final rp = widget.rp;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Your New Recovery Code',
                style: AppTypography.heading(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
              ),
              child: Center(
                child: SelectableText(
                  rp.recoveryCode ?? '—',
                  style: AppTypography.body(
                    color: theme.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '⚠️ This code will never be shown again.',
                style: AppTypography.caption(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: rp.recoveryCode ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recovery code copied!')),
                  );
                },
                icon: Icon(Icons.copy_rounded, color: theme.textColor, size: 16),
                label: Text(
                  'Copy Code',
                  style: AppTypography.body(color: theme.textColor, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _saved,
                  onChanged: (val) => setState(() => _saved = val ?? false),
                  activeColor: theme.accentColor,
                ),
                Expanded(
                  child: Text(
                    'I have saved my recovery code securely.',
                    style: AppTypography.body(color: theme.textColor, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saved
                    ? () {
                        rp.clearRecoveryCode();
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Continue',
                  style: AppTypography.button(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
