import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/relationship/presentation/profile/delete_account_confirmation_dialog.dart';
import 'package:days_together/features/relationship/presentation/profile/unlink_confirmation_dialog.dart';
import 'package:days_together/features/relationship/session_state.dart';

/// The "DANGER ZONE" divider plus the unlink/delete-account rows on
/// [RelationshipProfileScreen]. Extracted from its
/// `_buildDangerZoneDivider`/`_buildUnlinkButton`/`_buildDeleteAccountButton`
/// (Migration audit item 6) -- grouped into one widget since all three
/// always render together as a single section.
class DangerZoneSection extends StatelessWidget {
  const DangerZoneSection({
    super.key,
    required this.sessionState,
    required this.theme,
  });

  final SessionState sessionState;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    final partnerJoined = sessionState.partnerId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DangerZoneDivider(theme: theme),
        const SizedBox(height: 20),
        if (partnerJoined) ...[
          _UnlinkButton(theme: theme),
          const SizedBox(height: 16),
        ],
        _DeleteAccountButton(theme: theme),
      ],
    );
  }
}

class _DangerZoneDivider extends StatelessWidget {
  const _DangerZoneDivider({required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.redAccent.withValues(alpha: 0.15),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'DANGER ZONE',
                style: AppTypography.captionMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.redAccent,
                ).copyWith(letterSpacing: 1.5),
              ),
            ],
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.redAccent.withValues(alpha: 0.15),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

class _UnlinkButton extends StatelessWidget {
  const _UnlinkButton({required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: TextButton(
        onPressed: () => UnlinkConfirmationDialog.show(context, theme),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'Unlink Relationship',
          style: AppTypography.body(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
      ),
      child: TextButton(
        onPressed: () => DeleteAccountConfirmationDialog.show(context, theme),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'Delete Account',
          style: AppTypography.body(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
