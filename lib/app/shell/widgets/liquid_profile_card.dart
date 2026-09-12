import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/app/shell/widgets/mini_avatar.dart';
import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/features/relationship/session_state.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The two-avatar profile summary at the top of [SettingsTab]. Extracted
/// from its `_buildLiquidProfileCard` (Migration audit item 6).
class LiquidProfileCard extends StatelessWidget {
  const LiquidProfileCard({
    super.key,
    required this.session,
    required this.profile,
    required this.theme,
  });

  final SessionState session;
  final ProfileState profile;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    final partnerJoined = session.partnerId != null;

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 30,
      opacity: 0.1,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              MiniAvatar(
                path: profile.yourAvatarPath,
                name: profile.yourName ?? 'You',
                theme: theme,
              ),
              Icon(Icons.favorite_rounded, color: theme.accentColor, size: 28),
              MiniAvatar(
                path: partnerJoined ? profile.partnerAvatarPath : null,
                name: partnerJoined
                    ? (profile.partnerName ?? 'Partner')
                    : 'Waiting...',
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
