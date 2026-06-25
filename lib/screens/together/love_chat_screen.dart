import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/models/love_chat_model.dart';
import 'package:days_together/providers/love_chat_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/widgets/cached_avatar.dart';

class LoveChatScreen extends StatefulWidget {
  const LoveChatScreen({super.key});

  @override
  State<LoveChatScreen> createState() => _LoveChatScreenState();
}

class _LoveChatScreenState extends State<LoveChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _revealedMessageIds = {};

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(LoveChatProvider provider, String senderName) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    provider.sendMessage(text, senderName);
    _messageController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final rp = context.watch<RelationshipProvider>();
    final provider = context.watch<LoveChatProvider>();
    
    final yourName = rp.yourName ?? 'Me';
    final partnerName = rp.partnerName ?? 'Partner';
    final partnerJoined = rp.partnerId != null;

    final messages = provider.messages;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Premium Header
              _buildHeader(context, theme, rp, partnerJoined, partnerName),
              Divider(color: theme.textColor.withValues(alpha: 0.1), height: 1),

              // Chat Messages List
              Expanded(
                child: messages.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true, // Show latest messages at the bottom
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == 'you';

                          // Reversed list means:
                          // previous chronological message is at index + 1
                          final previousMessage = index < messages.length - 1 ? messages[index + 1] : null;
                          // next chronological message is at index - 1
                          final nextMessage = index > 0 ? messages[index - 1] : null;

                          final isFirstInGroup = previousMessage == null ||
                              previousMessage.senderId != message.senderId ||
                              message.createdAt.difference(previousMessage.createdAt).inMinutes >= 5;

                          final isLastInGroup = nextMessage == null ||
                              nextMessage.senderId != message.senderId ||
                              nextMessage.createdAt.difference(message.createdAt).inMinutes >= 5;

                          return _buildChatBubble(
                            context,
                            message,
                            isMe,
                            isFirstInGroup,
                            isLastInGroup,
                            theme,
                            provider,
                          );
                        },
                      ),
              ),
              Divider(color: theme.textColor.withValues(alpha: 0.1), height: 1),

              // Input Box
              _buildInputRow(provider, theme, yourName),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    dynamic theme,
    RelationshipProvider rp,
    bool partnerJoined,
    String partnerName,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
          ),
          const SizedBox(width: 4),
          CachedAvatar(
            path: partnerJoined ? rp.partnerAvatarPath : null,
            radius: 18,
            placeholderColor: theme.textColor.withValues(alpha: 0.1),
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
                        color: partnerJoined && rp.isPartnerOnline ? Colors.greenAccent : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      partnerJoined && rp.isPartnerOnline ? 'Active Now' : 'Offline',
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

  Widget _buildChatBubble(
    BuildContext context,
    LoveChatMessage message,
    bool isMe,
    bool isFirstInGroup,
    bool isLastInGroup,
    dynamic theme,
    LoveChatProvider provider,
  ) {
    final isRevealed = _revealedMessageIds.contains(message.id);

    // Grouped message bubble spacing
    final bottomPadding = isLastInGroup ? 14.0 : 3.0;

    // Calculate BorderRadius
    BorderRadius borderRadius;
    if (isMe) {
      if (isFirstInGroup && isLastInGroup) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        );
      } else if (isFirstInGroup) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        );
      } else if (isLastInGroup) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        );
      } else {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        );
      }
    } else {
      if (isFirstInGroup && isLastInGroup) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        );
      } else if (isFirstInGroup) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        );
      } else if (isLastInGroup) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        );
      } else {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Name and Time Header (only for the first message of a group)
          if (isFirstInGroup) ...[
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 6, bottom: 4),
              child: Row(
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Text(
                    isMe ? 'Me' : message.senderName,
                    style: AppTypography.bodyLarge(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MM/dd h:mm a').format(message.createdAt),
                    style: AppTypography.caption(
                      fontSize: 9,
                      color: theme.textColor.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Bubble Wrapper
          GestureDetector(
            onTap: () {
              setState(() {
                if (isRevealed) {
                  _revealedMessageIds.remove(message.id);
                } else {
                  _revealedMessageIds.add(message.id);
                }
              });
            },
            onLongPress: () => _showActions(context, message, provider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? theme.accentColor.withValues(alpha: 0.18)
                    : theme.textColor.withValues(alpha: 0.05),
                borderRadius: borderRadius,
                border: Border.all(
                  color: theme.textColor.withValues(alpha: 0.05),
                ),
              ),
              child: Text(
                message.content,
                style: AppTypography.body(
                  color: theme.textColor,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          ),

          // Tapped revealed timestamp
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: isRevealed
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      DateFormat('h:mm a').format(message.createdAt),
                      style: AppTypography.caption(
                        fontSize: 9,
                        color: theme.textColor.withValues(alpha: 0.38),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(LoveChatProvider provider, dynamic theme, String yourName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: GlassContainer(
              borderRadius: 24,
              opacity: 0.1,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _messageController,
                style: AppTypography.body(color: theme.textColor, fontSize: 14),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Say something loving...',
                  hintStyle: TextStyle(color: theme.textColor.withValues(alpha: 0.3), fontSize: 14),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(provider, yourName),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(provider, yourName),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: theme.accentColor,
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context, LoveChatMessage message, LoveChatProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassContainer(
        borderRadius: 24,
        opacity: 0.15,
        blur: 20,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: Text(
                  'Delete Message',
                  style: AppTypography.body(color: Colors.redAccent),
                ),
                onTap: () {
                  provider.deleteMessage(message.id);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(dynamic theme) {
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
            'No chat messages yet.',
            style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.3), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Send a message to start chatting!',
            style: AppTypography.bodyMedium(color: theme.accentColor.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
