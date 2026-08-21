import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/widgets/scale_drawing_painter.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/models/love_chat_model.dart';
import 'package:days_together/providers/noteit_provider.dart';
import 'package:days_together/providers/love_chat_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/widgets/storage_image.dart';
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
    context.watch<NoteitProvider>();
    
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

    final isScrapbook = message.content.startsWith('[scrapbook]:');
    NoteitItem? scrapbookItem;
    if (isScrapbook) {
      try {
        final payload = message.content.substring('[scrapbook]:'.length);
        if (payload.trim().startsWith('{')) {
          scrapbookItem = NoteitItem.fromJson(jsonDecode(payload));
        } else {
          final noteId = payload.trim();
          final noteitProvider = context.read<NoteitProvider>();
          try {
            scrapbookItem = noteitProvider.notes.firstWhere((n) => n.id == noteId);
          } catch (_) {
            scrapbookItem = NoteitItem(
              id: noteId,
              type: NoteitType.drawing,
              sender: isMe ? 'you' : 'partner',
              createdAt: message.createdAt,
            );
          }
        }
      } catch (e) {
        debugPrint('Failed to parse scrapbook chat message: $e');
      }
    }

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

    Widget bubbleContent;
    if (isScrapbook && scrapbookItem != null) {
      Widget canvasContent = const SizedBox.shrink();
      if (scrapbookItem.type == NoteitType.text) {
        canvasContent = Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          child: Text(
            scrapbookItem.content ?? '',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.lora(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        );
      } else if (scrapbookItem.type == NoteitType.drawing) {
        Widget drawingWidget;
        if (scrapbookItem.imagePath != null && File(scrapbookItem.imagePath!).existsSync()) {
          drawingWidget = Image.file(
            File(scrapbookItem.imagePath!),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        } else if (scrapbookItem.imageUrl != null && scrapbookItem.imageUrl!.isNotEmpty) {
          drawingWidget = StorageImage(
            bucket: StorageBuckets.loveNotes,
            storageRef: scrapbookItem.imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorWidget: (context) => const Icon(Icons.broken_image, size: 20, color: Colors.grey),
          );
        } else {
          drawingWidget = CustomPaint(
            painter: ScaleDrawingPainter(
              colorfulStrokes: NoteitItem.deserializeColorfulStrokes(scrapbookItem.content, theme.textColor),
              color: theme.textColor,
              strokeWidth: 2.0,
            ),
          );
        }
        canvasContent = drawingWidget;
      } else if (scrapbookItem.type == NoteitType.photo) {
        canvasContent = scrapbookItem.imagePath != null && File(scrapbookItem.imagePath!).existsSync()
            ? Image.file(
                File(scrapbookItem.imagePath!),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : scrapbookItem.imageUrl != null && scrapbookItem.imageUrl!.isNotEmpty
                ? StorageImage(
                    bucket: StorageBuckets.loveNotes,
                    storageRef: scrapbookItem.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorWidget: (context) => const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                  )
                : Center(
                    child: Icon(
                      Icons.photo_rounded,
                      color: theme.textColor.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  );
      }

      bubbleContent = Container(
        width: 180,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.backgroundColor.withValues(alpha: 0.95),
          borderRadius: borderRadius,
          border: Border.all(
            color: theme.textColor.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Polaroid-like square canvas
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: scrapbookItem.backgroundColor ?? theme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: canvasContent,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Caption
            Row(
              children: [
                Icon(
                  scrapbookItem.type == NoteitType.text
                      ? Icons.note_alt_rounded
                      : scrapbookItem.type == NoteitType.photo
                          ? Icons.image_rounded
                          : Icons.palette_rounded,
                  size: 11,
                  color: theme.accentColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    scrapbookItem.type == NoteitType.text
                        ? 'Scrapbook Note'
                        : scrapbookItem.type == NoteitType.photo
                            ? 'Scrapbook Photo'
                            : 'Scrapbook Doodle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      bubbleContent = Container(
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
      );
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
              if (isScrapbook && scrapbookItem != null) {
                _showEnlargeNoteDialog(context, scrapbookItem, theme);
              } else {
                setState(() {
                  if (isRevealed) {
                    _revealedMessageIds.remove(message.id);
                  } else {
                    _revealedMessageIds.add(message.id);
                  }
                });
              }
            },
            onLongPress: () => _showActions(context, message, provider),
            child: bubbleContent,
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
                  hintText: 'Write something sweet...',
                  hintStyle: AppTypography.body(color: theme.textColor.withValues(alpha: 0.3), fontSize: 14),
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
            'No messages here yet',
            style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.3), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Send a sweet note to start the conversation!',
            style: AppTypography.bodyMedium(color: theme.accentColor.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showEnlargeNoteDialog(BuildContext context, NoteitItem item, dynamic theme) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: item.backgroundColor ?? Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: theme.textColor.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: _buildWidgetContent(item, theme),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                item.sender == 'you' ? 'Sent by You' : 'Received from Partner',
                style: AppTypography.bodyLarge(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWidgetContent(NoteitItem item, dynamic theme) {
    if (item.imagePath != null && File(item.imagePath!).existsSync()) {
      return Image.file(
        File(item.imagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return StorageImage(
        bucket: StorageBuckets.loveNotes,
        storageRef: item.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    if (item.type == NoteitType.drawing) {
      return CustomPaint(
        painter: ScaleDrawingPainter(
          colorfulStrokes: NoteitItem.deserializeColorfulStrokes(item.content, theme.textColor),
          color: theme.textColor,
          strokeWidth: 3.5,
        ),
      );
    } else if (item.type == NoteitType.text) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Text(
          item.content ?? '',
          textAlign: TextAlign.center,
          style: AppTypography.lora(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: Colors.white,
            height: 1.4,
          ),
        ),
      );
    }
    return Container(color: Colors.grey);
  }
}
