import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/core/models/paging_status.dart';
import 'package:days_together/features/chat/domain/entities/love_chat_model.dart';
import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/features/chat/presentation/sheets/chat_message_actions_sheet.dart';
import 'package:days_together/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:days_together/features/chat/presentation/widgets/chat_empty_state.dart';
import 'package:days_together/shared/models/noteit_model.dart';
import 'package:days_together/shared/widgets/paged_list_footer.dart';

/// The scrollable message feed on [LoveChatScreen] -- consecutive-message
/// grouping (so only the first bubble of a burst shows the sender/time
/// header) plus the empty-state placeholder. Extracted from the screen's
/// inline `ListView.builder` and its `_buildEmptyState` (Migration audit
/// item 6). Scrolling up towards the oldest loaded message loads older
/// history (`LoveChatController.loadOlder`).
class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    this.paging = const PagingStatus(),
    required this.scrollController,
    required this.theme,
    required this.visibleNotes,
    required this.revealedMessageIds,
    required this.onToggleReveal,
    required this.notifier,
  });

  final List<LoveChatMessage> messages;

  /// Status of older history, shown at the top of the feed.
  final PagingStatus paging;
  final ScrollController scrollController;
  final LoveStoryTheme theme;
  final List<NoteitItem> visibleNotes;
  final Set<String> revealedMessageIds;
  final ValueChanged<String> onToggleReveal;
  final LoveChatController notifier;

  void _showActions(BuildContext context, LoveChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChatMessageActionsSheet(
        onDelete: () => notifier.deleteMessage(message.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && paging.loadMoreFailed) {
      // Nothing cached and the first page failed.
      return Center(
        child: PagedListFooter(
          status: paging,
          onRetry: notifier.retryLoad,
          color: theme.textColor,
        ),
      );
    }
    if (messages.isEmpty) {
      return ChatEmptyState(theme: theme);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // reverse: the end the list grows towards is the top (older).
        if (paging.canAutoLoad && isNearScrollEnd(n.metrics)) {
          notifier.loadOlder();
        }
        return false;
      },
      child: _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      reverse: true, // Show latest messages at the bottom
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      // + the older-history footer, rendered at the top.
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return PagedListFooter(
            status: paging,
            onRetry: notifier.retryLoad,
            color: theme.textColor,
            endLabel: messages.length > LoveChatController.maxLocalMessages
                ? 'This is where your story began 💕'
                : null,
          );
        }
        final message = messages[index];
        final isMe = message.senderId == 'you';

        // Reversed list means:
        // previous chronological message is at index + 1
        final previousMessage = index < messages.length - 1
            ? messages[index + 1]
            : null;
        // next chronological message is at index - 1
        final nextMessage = index > 0 ? messages[index - 1] : null;

        final isFirstInGroup =
            previousMessage == null ||
            previousMessage.senderId != message.senderId ||
            message.createdAt.difference(previousMessage.createdAt).inMinutes >=
                5;

        final isLastInGroup =
            nextMessage == null ||
            nextMessage.senderId != message.senderId ||
            nextMessage.createdAt.difference(message.createdAt).inMinutes >= 5;

        return ChatBubble(
          message: message,
          isMe: isMe,
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
          theme: theme,
          isRevealed: revealedMessageIds.contains(message.id),
          visibleNotes: visibleNotes,
          onToggleReveal: () => onToggleReveal(message.id),
          onLongPress: () => _showActions(context, message),
        );
      },
    );
  }
}
