import 'dart:io';
import 'package:flutter/material.dart';
import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/features/scrapbook/noteit_state.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/services/noteit_sync_manager.dart';
import 'package:days_together/shared/scale_drawing_painter.dart';
import 'package:days_together/shared/storage_image.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Historical grid feed of exchanged scrapbook notes, including sync indicators
/// and enlargement dialogs.
class NoteitHistoryPanel extends StatelessWidget {
  final LoveStoryTheme theme;
  final NoteitState state;
  final NoteitController notifier;

  const NoteitHistoryPanel({
    super.key,
    required this.theme,
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final list = state.visibleNotes;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 48,
              color: theme.textColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No scrapbook canvases exchanged yet.',
              style: AppTypography.body(
                color: theme.textColor.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final item = list[idx];
        return GestureDetector(
          onTap: () => showNoteitEnlargeDialog(context, item, theme),
          onLongPress: () => _confirmDelete(context, item),
          child: Container(
            decoration: BoxDecoration(
              color: item.backgroundColor ?? theme.textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: NoteitCanvasThumbnail(item: item),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.sender == 'you'
                            ? (item.syncStatus == SyncStatus.sending
                                ? '📤 Sending'
                                : item.syncStatus == SyncStatus.failed
                                ? '⚠️ Failed'
                                : '✅ Sent')
                            : 'Received',
                        style: AppTypography.bodyLarge(
                          fontSize: 8,
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (item.sender == 'you')
                    Positioned(
                      bottom: 6,
                      right: 8,
                      child: NoteitSyncStatusBadge(item: item, theme: theme),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, NoteitItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: Text(
          'Delete Canvas?',
          style: AppTypography.heading(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this canvas from history?',
          style: AppTypography.body(
            color: theme.textColor.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: Text(
              'Delete',
              style: AppTypography.button(color: Colors.redAccent),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              notifier.deleteNote(item.id);
            },
          ),
        ],
      ),
    );
  }
}

/// Sync status indicator badge for scrapbook items in the history panel.
class NoteitSyncStatusBadge extends StatelessWidget {
  final NoteitItem item;
  final LoveStoryTheme theme;

  const NoteitSyncStatusBadge({
    super.key,
    required this.item,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    switch (item.syncStatus) {
      case SyncStatus.sending:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      case SyncStatus.failed:
        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: theme.backgroundColor,
                title: Text(
                  'Sync Failed',
                  style: AppTypography.heading(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(
                  'This canvas note couldn\'t be sent to your partner. Would you like to try sending it again?',
                  style: AppTypography.body(
                    color: theme.textColor.withValues(alpha: 0.8),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: AppTypography.button(
                        color: theme.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      NoteitSyncManager.instance.retryTask(item.id);
                    },
                    child: Text(
                      'Retry Now',
                      style: AppTypography.button(color: theme.accentColor),
                    ),
                  ),
                ],
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.refresh_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
        );
      case SyncStatus.synced:
        return const SizedBox.shrink();
    }
  }
}

/// Displays an enlarged popup dialog showing the selected note item.
void showNoteitEnlargeDialog(BuildContext context, NoteitItem item, LoveStoryTheme theme) {
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
              child: NoteitCanvasThumbnail(item: item),
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
              item.sender == 'you'
                  ? (item.syncStatus == SyncStatus.sending
                        ? 'Sending Canvas...'
                        : item.syncStatus == SyncStatus.failed
                        ? 'Failed to Send'
                        : 'Sent by You')
                  : 'Received from Partner',
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

/// Thumbnail renderer for a scrapbook note item (image, drawing strokes, or text).
class NoteitCanvasThumbnail extends StatelessWidget {
  final NoteitItem item;

  const NoteitCanvasThumbnail({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
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
        placeholder: (context) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    if (item.type == NoteitType.drawing) {
      return CustomPaint(
        painter: ScaleDrawingPainter(
          colorfulStrokes: NoteitItem.deserializeColorfulStrokes(item.content, Colors.white),
          color: Colors.white,
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
