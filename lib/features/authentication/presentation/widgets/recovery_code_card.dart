import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The recovery-code display + copy card on [CreateCoupleCodeScreen].
/// Extracted from its inline `build()` (Migration audit item 6) -- the
/// copied-flag state stays on the screen, matching how this app's other
/// extracted forms keep state on their own State.
class RecoveryCodeCard extends StatelessWidget {
  const RecoveryCodeCard({
    super.key,
    required this.recoveryCode,
    required this.copied,
    required this.onCopy,
    required this.theme,
  });

  final String? recoveryCode;
  final bool copied;
  final VoidCallback onCopy;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Recovery Code',
            style: AppTypography.body(
              color: theme.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            recoveryCode ?? '—',
            style: AppTypography.body(
              color: theme.accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '⚠️ This code will never be shown again. Use it to recover your workspace if you disconnect.',
            style: AppTypography.caption(
              color: theme.textColor.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onCopy,
              icon: Icon(
                copied ? Icons.check_circle_outline : Icons.copy_all_rounded,
                size: 16,
              ),
              label: Text(copied ? 'Copied!' : 'Copy Recovery Code'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.textColor,
                side: BorderSide(
                  color: theme.textColor.withValues(alpha: 0.15),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
