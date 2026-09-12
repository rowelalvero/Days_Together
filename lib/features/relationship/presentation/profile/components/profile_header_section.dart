import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/relationship/presentation/profile/edit_profile_dialog.dart';
import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/features/relationship/session_state.dart';
import 'package:days_together/shared/widgets/cached_avatar.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The couple's avatars, names, and "Edit Profile" button at the top of
/// [RelationshipProfileScreen]'s scroll view. Extracted from its
/// `_buildHeaderSection` (plus its `_buildAvatarWidget`/
/// `_buildAvatarPlaceholder` helpers) as part of Migration audit item 6.
class ProfileHeaderSection extends StatelessWidget {
  const ProfileHeaderSection({
    super.key,
    required this.sessionState,
    required this.profileState,
    required this.theme,
  });

  final SessionState sessionState;
  final ProfileState profileState;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    final partnerJoined = sessionState.partnerId != null;
    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      opacity: 0.1,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ProfileAvatar(
                path: profileState.yourAvatarPath,
                name: profileState.yourName ?? 'You',
                theme: theme,
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: theme.accentColor,
                  size: 24,
                ),
              ),
              if (partnerJoined)
                _ProfileAvatar(
                  path: profileState.partnerAvatarPath,
                  name: profileState.partnerName ?? 'Partner',
                  theme: theme,
                )
              else
                _ProfileAvatarPlaceholder(theme: theme),
            ],
          ),
          const SizedBox(height: 32),
          if (partnerJoined) ...[
            Text(
              '${profileState.yourName ?? 'You'} & ${profileState.partnerName ?? 'Partner'}',
              style: AppTypography.cormorant(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'CONNECTED & IN LOVE',
                style: AppTypography.captionMono(
                  fontSize: 9,
                  color: theme.accentColor,
                  fontWeight: FontWeight.w800,
                ).copyWith(letterSpacing: 1),
              ),
            ),
          ] else ...[
            Text(
              profileState.yourName ?? 'You',
              style: AppTypography.heading(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for your partner to connect...',
              style: AppTypography.body(
                fontSize: 14,
                color: theme.textColor.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => EditProfileDialog.show(context, theme),
            icon: Icon(Icons.edit_rounded, color: theme.textColor, size: 16),
            label: Text(
              'Edit Profile',
              style: AppTypography.body(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.textColor.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.path,
    required this.name,
    required this.theme,
  });

  final String? path;
  final String name;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CachedAvatar(
          path: path,
          radius: 44,
          // iconSize matches AppAvatar's old default (radius * 1.2) before
          // the Phase 7b merge into CachedAvatar, whose own default is
          // just radius -- passed explicitly here to keep this call site's
          // rendered icon size unchanged.
          iconSize: 44 * 1.2,
          backgroundColor: theme.textColor.withValues(alpha: 0.1),
          iconColor: theme.textColor.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 90,
          child: Text(
            name,
            style: AppTypography.body(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatarPlaceholder extends StatelessWidget {
  const _ProfileAvatarPlaceholder({required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CachedAvatar(
          radius: 44,
          iconSize: 44 * 1.2,
          backgroundColor: theme.textColor.withValues(alpha: 0.1),
          iconColor: theme.textColor.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 12),
        Text(
          'Waiting...',
          style: AppTypography.body(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: theme.textColor.withValues(alpha: 0.38),
          ),
        ),
      ],
    );
  }
}
