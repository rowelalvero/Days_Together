import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// Shown inside [CurrentlyCard] in place of its live-presence layout while
/// `session.partnerId` is still null.
///
/// Nothing in the paired layout (partner avatar, online status, Love Tap,
/// "no activity shared yet", streak) means anything before a partner has
/// actually joined -- tapping Love Tap would silently do nothing, and "no
/// activity shared yet" implies a partner who hasn't posted, not one who
/// doesn't exist yet. This replaces all of it with the couple code itself
/// and a one-tap share action, rather than sending the user to a separate
/// screen just to see a code that already exists.
class PartnerInvitePrompt extends StatelessWidget {
  const PartnerInvitePrompt({
    super.key,
    required this.theme,
    required this.code,
    required this.copied,
    required this.onCopy,
    required this.onShare,
  });

  final LoveStoryTheme theme;
  final String? code;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Two overlapping circles: "you" (filled, present) and "your
        // partner" (outlined, not yet here) -- not yet touching.
        SizedBox(
          width: 64,
          height: 40,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                child: _PersonCircle(
                  background: theme.textColor.withValues(alpha: 0.08),
                  iconColor: theme.textColor.withValues(alpha: 0.5),
                ),
              ),
              Positioned(
                left: 24,
                child: _PersonCircle(
                  background: theme.accentColor.withValues(alpha: 0.12),
                  iconColor: theme.accentColor,
                  borderColor: theme.accentColor.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Waiting for your partner',
          style: AppTypography.body(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Share your code so they can join your story.',
          textAlign: TextAlign.center,
          style: AppTypography.caption(
            fontSize: 12,
            color: theme.textColor.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.textColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.textColor.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR CODE',
                      style: AppTypography.caption(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor.withValues(alpha: 0.4),
                      ).copyWith(letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      code ?? '· · · · · ·',
                      style: AppTypography.body(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ).copyWith(letterSpacing: 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _CopyCodeButton(
                theme: theme,
                copied: copied,
                onTap: code == null ? null : onCopy,
              ),
              const SizedBox(width: 8),
              _SendCodeButton(
                theme: theme,
                onTap: code == null ? null : onShare,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonCircle extends StatelessWidget {
  const _PersonCircle({
    required this.background,
    required this.iconColor,
    this.borderColor,
  });

  final Color background;
  final Color iconColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.5)
            : null,
      ),
      child: Icon(Icons.person_rounded, color: iconColor, size: 20),
    );
  }
}

/// The "copy" action beside the code: swaps to a checkmark briefly after
/// copying, mirroring how this app's other copy-to-clipboard buttons
/// (e.g. CreateCoupleCodeScreen's) confirm the tap landed.
class _CopyCodeButton extends StatelessWidget {
  const _CopyCodeButton({
    required this.theme,
    required this.copied,
    required this.onTap,
  });

  final LoveStoryTheme theme;
  final bool copied;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: enabled ? 0.06 : 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.textColor.withValues(alpha: enabled ? 0.12 : 0.05),
          ),
        ),
        child: Icon(
          copied ? Icons.check_rounded : Icons.copy_rounded,
          color: theme.textColor.withValues(alpha: enabled ? 0.7 : 0.25),
          size: 20,
        ),
      ),
    );
  }
}

/// The "send" action beside the code: tappable to open the native share
/// sheet.
class _SendCodeButton extends StatelessWidget {
  const _SendCodeButton({required this.theme, required this.onTap});

  final LoveStoryTheme theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: theme.accentColor.withValues(alpha: enabled ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.accentColor.withValues(alpha: enabled ? 0.3 : 0.1),
          ),
        ),
        child: Icon(
          Icons.send_rounded,
          color: theme.accentColor.withValues(alpha: enabled ? 1.0 : 0.3),
          size: 20,
        ),
      ),
    );
  }
}
