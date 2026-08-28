import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/features/chat/love_chat_state.dart';
import 'package:days_together/core/scrapbook_ref.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/services/date_helper.dart';

/// Bento card for Love Chat on the dashboard.
/// Previews the latest shared sweet message or scrapbook doodle.
class LoveChatBentoCard extends StatelessWidget {
  final LoveStoryTheme theme;

  const LoveChatBentoCard({super.key, required this.theme});

  String _formatRelativeTime(DateTime dateTime) =>
      DateHelper.formatRelativeTimeShort(dateTime);

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final chat = ref.watch(loveChatControllerProvider);
        final messages = chat.messages;
        final latest = messages.isNotEmpty ? messages.first : null;

        String footerText = 'Share private memories';
        if (latest != null) {
          footerText = 'Last active: ${_formatRelativeTime(latest.createdAt)}';
        }

        return InkWell(
          onTap: () => context.push(Routes.chat),
          borderRadius: BorderRadius.circular(24),
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'CHAT',
                        style: AppTypography.cardCategory(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: theme.accentColor,
                        ).copyWith(letterSpacing: 0.5),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: theme.accentColor,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Chat Space',
                  style: AppTypography.title(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildLoveChatContent(context, chat),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        footerText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.captionMono(
                          fontSize: 10,
                          color: theme.textColor.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Text(
                          'Chat Now',
                          style: AppTypography.button(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: theme.accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: theme.accentColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoveChatContent(BuildContext context, LoveChatState chat) {
    final messages = chat.messages;

    if (messages.isEmpty) {
      return Text(
        'Send sweet notes and real-time love taps to your partner! 💓',
        style: AppTypography.bodyMedium(
          fontSize: 12,
          color: theme.textColor.withValues(alpha: 0.7),
          height: 1.4,
        ),
      );
    }

    final latest = messages.first;
    final isMe = latest.senderId == 'you';

    String displayContent = latest.content;
    if (ScrapbookRef.fromChatPayload(displayContent) != null) {
      displayContent = 'Shared a scrapbook doodle 🎨';
    } else if (displayContent.trim().startsWith('{')) {
      displayContent = 'Shared a scrapbook doodle 🎨';
    }

    return Row(
      children: [
        Icon(Icons.maps_ugc_rounded, color: theme.accentColor, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMe ? 'You' : latest.senderName,
                style: AppTypography.caption(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor.withValues(alpha: 0.54),
                ),
              ),
              Text(
                displayContent,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium(
                  fontSize: 12,
                  color: theme.textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
