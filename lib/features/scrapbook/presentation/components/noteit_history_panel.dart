import 'dart:io';
import 'package:flutter/material.dart';
import 'package:days_together/core/storage/storage_url_service.dart';
import 'package:days_together/core/utils/date_helper.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/features/scrapbook/noteit_state.dart';
import 'package:days_together/shared/models/noteit_model.dart';
import 'package:days_together/features/scrapbook/data/noteit_sync_manager.dart';
import 'package:days_together/shared/widgets/scale_drawing_painter.dart';
import 'package:days_together/shared/widgets/paged_list_footer.dart';
import 'package:days_together/shared/widgets/storage_image.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// Historical grid feed of exchanged scrapbook notes, including sync indicators
/// and enlargement dialogs. Paged: the next page of older notes loads as the
/// grid nears its end (see `NoteitController.loadMore`).
class NoteitHistoryPanel extends StatelessWidget {
  final LoveStoryTheme theme;
  final NoteitState state;
  final NoteitController notifier;

  /// Switches to the canvas tab; drives the empty state's call to action.
  final VoidCallback? onStartCanvas;

  const NoteitHistoryPanel({
    super.key,
    required this.theme,
    required this.state,
    required this.notifier,
    this.onStartCanvas,
  });

  @override
  Widget build(BuildContext context) {
    final list = state.visibleNotes;
    if (list.isEmpty && state.paging.loadMoreFailed) {
      // Nothing cached and the first page failed.
      return Center(
        child: PagedListFooter(
          status: state.paging,
          onRetry: notifier.retryLoad,
          color: theme.textColor,
        ),
      );
    }
    if (list.isEmpty) {
      return _EmptyHistory(theme: theme, onStartCanvas: onStartCanvas);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (state.paging.canAutoLoad && isNearScrollEnd(n.metrics)) {
          notifier.loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: list.length,
              itemBuilder: (ctx, idx) => _tile(context, list[idx]),
            ),
          ),
          SliverToBoxAdapter(
            child: PagedListFooter(
              status: state.paging,
              onRetry: notifier.retryLoad,
              color: theme.textColor,
              endLabel: list.length > NoteitController.pageSize
                  ? "That's every note 💌"
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, NoteitItem item) {
    final fromYou = item.sender == 'you';
    final when = DateHelper.formatRelativeTimeShort(item.createdAt);
    return Semantics(
      button: true,
      label:
          '${fromYou ? 'Sent by you' : 'From your partner'}, $when. '
          '${_statusLabel(item) ?? ''}',
      onLongPressHint: 'Delete',
      excludeSemantics: true,
      onTap: () => _enlarge(context, item),
      onLongPress: () => _confirmDelete(context, item),
      child: Material(
        color: theme.textColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(theme.radii.md + 4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _enlarge(context, item),
          onLongPress: () => _confirmDelete(context, item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(theme.radii.md),
                    child: ColoredBox(
                      color: noteitThumbnailBackdrop(item),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: NoteitCanvasThumbnail(item: item),
                          ),
                          if (fromYou && item.syncStatus != SyncStatus.synced)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: NoteitSyncStatusBadge(
                                item: item,
                                theme: theme,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                child: Row(
                  children: [
                    Icon(
                      fromYou
                          ? Icons.north_east_rounded
                          : Icons.south_west_rounded,
                      size: 14,
                      color: fromYou
                          ? theme.textColor.withValues(alpha: 0.7)
                          : theme.accentColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        fromYou ? 'You' : 'Partner',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.textColor,
                        ),
                      ),
                    ),
                    Text(
                      when,
                      style: AppTypography.caption(
                        fontSize: 12,
                        color: theme.textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enlarge(BuildContext context, NoteitItem item) {
    showNoteitEnlargeDialog(
      context,
      item,
      theme,
      onDelete: () => notifier.deleteNote(item.id),
    );
  }

  void _confirmDelete(BuildContext context, NoteitItem item) {
    confirmNoteitDelete(context, theme).then((confirmed) {
      if (confirmed) notifier.deleteNote(item.id);
    });
  }
}

String? _statusLabel(NoteitItem item) {
  if (item.sender != 'you') return null;
  return switch (item.syncStatus) {
    SyncStatus.sending => 'Sending',
    SyncStatus.failed => 'Failed to send',
    SyncStatus.synced => null,
  };
}

/// Shared "delete this canvas?" confirmation; resolves true on confirm.
Future<bool> confirmNoteitDelete(
  BuildContext context,
  LoveStoryTheme theme,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: theme.backgroundColor,
      title: Text(
        'Delete canvas?',
        style: AppTypography.heading(
          color: theme.textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        'This removes it from the scrapbook for both of you.',
        style: AppTypography.body(
          color: theme.textColor.withValues(alpha: 0.85),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'Keep',
            style: AppTypography.button(color: theme.textColor),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Delete',
            style: AppTypography.button(
              color: theme.semantic.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.theme, required this.onStartCanvas});

  final LoveStoryTheme theme;
  final VoidCallback? onStartCanvas;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: 40,
                color: theme.accentColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your scrapbook is empty',
              textAlign: TextAlign.center,
              style: AppTypography.heading(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Doodles, notes and photos you send each other will be kept here.',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                color: theme.textColor.withValues(alpha: 0.75),
              ),
            ),
            if (onStartCanvas != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onStartCanvas,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: theme.onAccentColor,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                icon: const Icon(Icons.draw_rounded),
                label: Text(
                  'Make the first one',
                  style: AppTypography.button(
                    color: theme.onAccentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sync status indicator badge for scrapbook items in the history panel.
/// Sending shows a spinner; failed is a tappable "Retry" chip.
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
        return Semantics(
          label: 'Sending',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(theme.radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Sending',
                  style: AppTypography.caption(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      case SyncStatus.failed:
        return Tooltip(
          message: 'Couldn\'t send. Tap to retry.',
          child: Material(
            color: theme.semantic.error,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _confirmRetry(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Retry',
                        style: AppTypography.caption(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      case SyncStatus.synced:
        return const SizedBox.shrink();
    }
  }

  void _confirmRetry(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: Text(
          'Couldn\'t send',
          style: AppTypography.heading(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This canvas didn\'t reach your partner. Try sending it again?',
          style: AppTypography.body(
            color: theme.textColor.withValues(alpha: 0.85),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Not now',
              style: AppTypography.button(color: theme.textColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              NoteitSyncManager.instance.retryTask(item.id);
            },
            child: Text(
              'Retry now',
              style: AppTypography.button(
                color: theme.accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays an enlarged popup dialog showing the selected note item, sized
/// to the screen, with its sender/time and an optional delete action.
void showNoteitEnlargeDialog(
  BuildContext context,
  NoteitItem item,
  LoveStoryTheme theme, {
  VoidCallback? onDelete,
}) {
  final fromYou = item.sender == 'you';
  final status = _statusLabel(item);
  final caption = [
    fromYou ? 'Sent by you' : 'From your partner',
    DateHelper.formatRelativeTimeShort(item.createdAt),
    ?status,
  ].join(' · ');

  showDialog(
    context: context,
    builder: (ctx) {
      final side = (MediaQuery.sizeOf(ctx).width - 48).clamp(200.0, 480.0);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                color: noteitThumbnailBackdrop(item),
                borderRadius: BorderRadius.circular(theme.radii.lg + 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(theme.radii.lg + 4),
                child: NoteitCanvasThumbnail(item: item),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              decoration: BoxDecoration(
                color: theme.backgroundColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(theme.radii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      caption,
                      style: AppTypography.bodyLarge(
                        color: theme.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Delete',
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: theme.semantic.error,
                      ),
                      onPressed: () async {
                        final confirmed = await confirmNoteitDelete(ctx, theme);
                        if (!confirmed || !ctx.mounted) return;
                        Navigator.pop(ctx);
                        onDelete();
                      },
                    ),
                  IconButton(
                    tooltip: 'Close',
                    icon: Icon(Icons.close_rounded, color: theme.textColor),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Backdrop behind a thumbnail when the note carries no background color.
/// Rendered canvases are opaque PNGs, but legacy drawing/text notes paint
/// white strokes and text, so they need a dark backdrop to be visible.
Color noteitThumbnailBackdrop(NoteitItem item) {
  if (item.backgroundColor != null) return item.backgroundColor!;
  final hasImage =
      item.imagePath != null ||
      (item.imageUrl != null && item.imageUrl!.isNotEmpty);
  return hasImage ? Colors.white : const Color(0xFF2B2235);
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
        placeholder: (context) => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.grey),
        ),
      );
    }

    if (item.type == NoteitType.drawing) {
      return CustomPaint(
        painter: ScaleDrawingPainter(
          colorfulStrokes: NoteitItem.deserializeColorfulStrokes(
            item.content,
            Colors.white,
          ),
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
