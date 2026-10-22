import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/authentication/presentation/widgets/auth_page_frame.dart';

/// Step 2 of [CreateCoupleCodeScreen]: the one-time recovery code. Tinted
/// with the semantic warning color because losing it is the one mistake on
/// this screen that can't be undone. The copied-flag state stays on the
/// screen.
class RecoveryCodeCard extends StatelessWidget {
  const RecoveryCodeCard({
    super.key,
    required this.recoveryCode,
    required this.copied,
    required this.onCopy,
    required this.theme,
    this.footer,
  });

  final String? recoveryCode;
  final bool copied;
  final VoidCallback onCopy;
  final LoveStoryTheme theme;

  /// Rendered at the bottom of the card -- the "I've saved it" confirmation.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final warning = theme.semantic.warning;
    final code = recoveryCode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: authCardDecoration(
        theme,
        border: warning.withValues(alpha: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: warning, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Shown only once. Keep it somewhere safe, like a password '
                  'manager. You\'ll need it to get back in on a new phone.',
                  style: AppTypography.body(
                    fontSize: 14,
                    color: theme.textColor,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: theme.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(theme.radii.sm + 4),
              border: Border.all(
                color: theme.textColor.withValues(alpha: 0.12),
              ),
            ),
            child: code == null
                ? Text(
                    'No longer available on this device. You can make a new '
                    'one later from your Relationship profile.',
                    style: AppTypography.body(
                      fontSize: 14,
                      color: theme.textColor.withValues(alpha: 0.75),
                    ),
                  )
                : SelectableText(
                    code,
                    style: AppTypography.bodyMono(
                      color: theme.textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ).copyWith(letterSpacing: 0.5, height: 1.4),
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: code == null ? null : onCopy,
              icon: Icon(
                copied ? Icons.check_rounded : Icons.copy_all_rounded,
                size: 18,
              ),
              label: Text(
                copied ? 'Copied!' : 'Copy Recovery Code',
                style: AppTypography.body(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.textColor,
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: theme.textColor.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.radii.md - 4),
                ),
              ),
            ),
          ),
          if (footer != null) ...[const SizedBox(height: 4), footer!],
        ],
      ),
    );
  }
}
