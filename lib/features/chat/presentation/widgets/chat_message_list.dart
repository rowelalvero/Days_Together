import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/chat/domain/entities/love_chat_model.dart';
import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/features/chat/presentation/sheets/chat_message_actions_sheet.dart';
import 'package:days_together/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:days_together/features/chat/presentation/widgets/chat_empty_state.dart';
import 'package:days_together/shared/models/noteit_model.dart';

/// The scrollable message feed on [LoveChatScreen] -- consecutive-message
/// grouping (so only the first bubble of a burst shows the sender/time
/// header) plus the empty-state placeholder. Extracted from the screen's
/// inline `ListView.builder` and its `_buildEmptyState` (Migration audit
/// item 6).
class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.theme,
    required this.visibleNotes,
    required this.revealedMessageIds,
    required this.onToggleReveal,
    required this.notifier,
  });

  final List<LoveChatMessage> messages;
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
    if (messages.isEmpty) {
      return ChatEmptyState(theme: theme);
    }

    return ListView.builder(
      controller: scrollController,
      reverse: true, // Show latest messages at the bottom
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
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
