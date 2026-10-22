import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The placeholder shown on [LoveChatScreen] before any messages exist.
/// Extracted from its `_buildEmptyState` (Migration audit item 6).
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: theme.textColor.withValues(alpha: 0.24),
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages here yet',
            style: AppTypography.body(
              color: theme.textColor.withValues(alpha: 0.3),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Send a sweet note to start the conversation!',
            style: AppTypography.bodyMedium(
              color: theme.accentColor.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
