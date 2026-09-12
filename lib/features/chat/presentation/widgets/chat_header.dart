import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/widgets/cached_avatar.dart';

/// The back button, partner avatar/name, and online-status row at the top
/// of [LoveChatScreen]. Extracted from its `_buildHeader` (Migration audit
/// item 6).
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.theme,
    required this.partnerAvatarPath,
    required this.isPartnerOnline,
    required this.partnerJoined,
    required this.partnerName,
  });

  final LoveStoryTheme theme;
  final String? partnerAvatarPath;
  final bool isPartnerOnline;
  final bool partnerJoined;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: theme.textColor,
            ),
          ),
          const SizedBox(width: 4),
          CachedAvatar(
            path: partnerJoined ? partnerAvatarPath : null,
            radius: 18,
            backgroundColor: theme.textColor.withValues(alpha: 0.1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partnerJoined ? partnerName : 'Waiting for Partner...',
                  style: AppTypography.bodyLarge(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: partnerJoined && isPartnerOnline
                            ? Colors.greenAccent
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      partnerJoined && isPartnerOnline
                          ? 'Active Now'
                          : 'Offline',
                      style: AppTypography.bodyMedium(
                        fontSize: 11,
                        color: theme.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
