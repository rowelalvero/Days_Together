import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/core/models/scrapbook_ref.dart';
import 'package:days_together/core/storage/storage_url_service.dart';
import 'package:days_together/features/chat/domain/entities/love_chat_model.dart';
import 'package:days_together/features/chat/presentation/dialogs/enlarged_note_dialog.dart';
import 'package:days_together/shared/models/noteit_model.dart';
import 'package:days_together/shared/widgets/scale_drawing_painter.dart';
import 'package:days_together/shared/widgets/storage_image.dart';

/// A single message row on [LoveChatScreen]: the sender/time header (for
/// the first message of a consecutive group), the bubble itself (a plain
/// text bubble, or a Polaroid-style card for a scrapbook-mirror message),
/// and its tap-to-reveal timestamp. Extracted from the screen's
/// `_buildChatBubble` (Migration audit item 6).
///
/// [visibleNotes] resolves a scrapbook-mirror message's referenced note by
/// id -- passed in rather than watched here, since the screen already
/// watches `noteitControllerProvider` once for the whole message list.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.theme,
    required this.isRevealed,
    required this.visibleNotes,
    required this.onToggleReveal,
    required this.onLongPress,
  });

  final LoveChatMessage message;
  final bool isMe;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final LoveStoryTheme theme;
  final bool isRevealed;
  final List<NoteitItem> visibleNotes;
  final VoidCallback onToggleReveal;
  final VoidCallback onLongPress;

  BorderRadius _borderRadius() {
    if (isMe) {
      if (isFirstInGroup && isLastInGroup) {
        return const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        );
      } else if (isFirstInGroup) {
        return const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        );
      } else if (isLastInGroup) {
        return const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        );
      }
      return const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(4),
      );
    }
    if (isFirstInGroup && isLastInGroup) {
      return const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(16),
      );
    } else if (isFirstInGroup) {
      return const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(16),
      );
    } else if (isLastInGroup) {
      return const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    }
    return const BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(4),
      bottomRight: Radius.circular(16),
    );
  }

  NoteitItem? _resolveScrapbookItem(ScrapbookRef ref) {
    // ScrapbookRef.itemId is "whatever followed the prefix" -- for a
    // genuinely old message that predates ScrapbookShareUseCase, that may
    // still be a JSON blob rather than a bare item ID, which the branch
    // below handles unchanged.
    final payload = ref.itemId;
    try {
      if (payload.trim().startsWith('{')) {
        return NoteitItem.fromJson(jsonDecode(payload));
      }
      final noteId = payload.trim();
      try {
        return visibleNotes.firstWhere((n) => n.id == noteId);
      } catch (_) {
        return NoteitItem(
          id: noteId,
          type: NoteitType.drawing,
          sender: isMe ? 'you' : 'partner',
          createdAt: message.createdAt,
        );
      }
    } catch (e) {
      debugPrint('Failed to parse scrapbook chat message: $e');
      return null;
    }
  }

  Widget _scrapbookBubble(NoteitItem scrapbookItem, BorderRadius borderRadius) {
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
      if (scrapbookItem.imagePath != null &&
          File(scrapbookItem.imagePath!).existsSync()) {
        drawingWidget = Image.file(
          File(scrapbookItem.imagePath!),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else if (scrapbookItem.imageUrl != null &&
          scrapbookItem.imageUrl!.isNotEmpty) {
        drawingWidget = StorageImage(
          bucket: StorageBuckets.loveNotes,
          storageRef: scrapbookItem.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorWidget: (context) =>
              const Icon(Icons.broken_image, size: 20, color: Colors.grey),
        );
      } else {
        drawingWidget = CustomPaint(
          painter: ScaleDrawingPainter(
            colorfulStrokes: NoteitItem.deserializeColorfulStrokes(
              scrapbookItem.content,
              theme.textColor,
            ),
            color: theme.textColor,
            strokeWidth: 2.0,
          ),
        );
      }
      canvasContent = drawingWidget;
    } else if (scrapbookItem.type == NoteitType.photo) {
      canvasContent =
          scrapbookItem.imagePath != null &&
              File(scrapbookItem.imagePath!).existsSync()
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
              errorWidget: (context) =>
                  const Icon(Icons.broken_image, size: 20, color: Colors.grey),
            )
          : Center(
              child: Icon(
                Icons.photo_rounded,
                color: theme.textColor.withValues(alpha: 0.6),
                size: 24,
              ),
            );
    }

    return Container(
      width: 180,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.95),
        borderRadius: borderRadius,
        border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
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
                color:
                    scrapbookItem.backgroundColor ??
                    theme.accentColor.withValues(alpha: 0.1),
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
  }

  Widget _textBubble(BorderRadius borderRadius) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? theme.accentColor.withValues(alpha: 0.18)
            : theme.textColor.withValues(alpha: 0.05),
        borderRadius: borderRadius,
        border: Border.all(color: theme.textColor.withValues(alpha: 0.05)),
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

  @override
  Widget build(BuildContext context) {
    final scrapbookRef = ScrapbookRef.fromChatPayload(message.content);
    final isScrapbook = scrapbookRef != null;
    final scrapbookItem = scrapbookRef != null
        ? _resolveScrapbookItem(scrapbookRef)
        : null;

    final bottomPadding = isLastInGroup ? 14.0 : 3.0;
    final borderRadius = _borderRadius();

    final bubbleContent = isScrapbook && scrapbookItem != null
        ? _scrapbookBubble(scrapbookItem, borderRadius)
        : _textBubble(borderRadius);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Name and Time Header (only for the first message of a group)
          if (isFirstInGroup) ...[
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 6, bottom: 4),
              child: Row(
                mainAxisAlignment: isMe
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
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
                showDialog(
                  context: context,
                  builder: (ctx) =>
                      EnlargedNoteDialog(item: scrapbookItem, theme: theme),
                );
              } else {
                onToggleReveal();
              }
            },
            onLongPress: onLongPress,
            child: bubbleContent,
          ),

          // Tapped revealed timestamp
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: isRevealed
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
}
