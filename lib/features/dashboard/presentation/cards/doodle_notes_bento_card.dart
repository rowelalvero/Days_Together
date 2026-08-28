import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/features/scrapbook/noteit_state.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/shared/scale_drawing_painter.dart';
import 'package:days_together/shared/storage_image.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/services/date_helper.dart';

/// Bento card for the Scrapbook / NoteIt feature on the dashboard.
/// Displays the latest drawing, shared note text, or photo exchanged between partners.
class DoodleNotesBentoCard extends StatefulWidget {
  final LoveStoryTheme theme;

  const DoodleNotesBentoCard({super.key, required this.theme});

  @override
  State<DoodleNotesBentoCard> createState() => _DoodleNotesBentoCardState();
}

class _DoodleNotesBentoCardState extends State<DoodleNotesBentoCard> {
  Timer? _timer;
  final Map<String, bool> _fileExistsCache = {};

  bool _cachedFileExists(String path) =>
      _fileExistsCache.putIfAbsent(path, () => File(path).existsSync());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRelativeTime(DateTime dateTime) =>
      DateHelper.formatRelativeTimeLong(dateTime);

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final noteit = ref.watch(noteitControllerProvider);
        final notes = noteit.visibleNotes;
        final latest = notes.isNotEmpty ? notes.first : null;

        String footerText = 'No shared notes';
        if (latest != null) {
          final senderName = latest.sender == 'you' ? 'You' : 'Partner';
          footerText = '$senderName • ${_formatRelativeTime(latest.createdAt)}';
        }

        return InkWell(
          onTap: () => context.push(Routes.notes),
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
                        color: widget.theme.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'SCRAPBOOK',
                        style: AppTypography.cardCategory(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: widget.theme.accentColor,
                        ).copyWith(letterSpacing: 0.5),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.theme.accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.draw_outlined,
                          color: widget.theme.accentColor,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Scrapbook',
                  style: AppTypography.title(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: widget.theme.textColor,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: widget.theme.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildNoteItContent(context, noteit),
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
                          color: widget.theme.textColor.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Text(
                          'Draw & Write',
                          style: AppTypography.button(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: widget.theme.accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: widget.theme.accentColor,
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

  Widget _buildNoteItContent(BuildContext context, NoteitState noteit) {
    final notes = noteit.visibleNotes;

    if (notes.isEmpty) {
      return Text(
        'Draw a sketch, write a note, or share a photo to surprise your partner! 💌',
        style: AppTypography.bodyMedium(
          fontSize: 12,
          color: widget.theme.textColor.withValues(alpha: 0.7),
          height: 1.4,
        ),
      );
    }

    final latest = notes.first;
    String previewText = '';
    Widget canvasContent = const SizedBox.shrink();

    if (latest.type == NoteitType.text) {
      previewText = latest.content ?? '';
      canvasContent = Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(
          latest.content ?? '',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
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
    } else if (latest.type == NoteitType.drawing) {
      previewText = 'Doodle Drawing 🎨';
      Widget drawingWidget;
      if (latest.imagePath != null && _cachedFileExists(latest.imagePath!)) {
        drawingWidget = Image.file(
          File(latest.imagePath!),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else if (latest.imageUrl != null && latest.imageUrl!.isNotEmpty) {
        drawingWidget = StorageImage(
          bucket: StorageBuckets.loveNotes,
          storageRef: latest.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorWidget: (context) =>
              const Icon(Icons.broken_image, size: 24, color: Colors.grey),
        );
      } else {
        drawingWidget = CustomPaint(
          painter: ScaleDrawingPainter(
            colorfulStrokes: NoteitItem.deserializeColorfulStrokes(
              latest.content,
              widget.theme.textColor,
            ),
            color: widget.theme.textColor,
            strokeWidth: 2.5,
          ),
        );
      }
      canvasContent = drawingWidget;
    } else if (latest.type == NoteitType.photo) {
      previewText = 'Shared Photo 📸';
      canvasContent =
          latest.imagePath != null && _cachedFileExists(latest.imagePath!)
              ? Image.file(
                  File(latest.imagePath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              : latest.imageUrl != null && latest.imageUrl!.isNotEmpty
              ? StorageImage(
                  bucket: StorageBuckets.loveNotes,
                  storageRef: latest.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: (context) => const Icon(
                    Icons.photo_rounded,
                    color: Colors.grey,
                  ),
                )
              : Center(
                  child: Icon(
                    Icons.photo_rounded,
                    color: widget.theme.textColor.withValues(alpha: 0.6),
                    size: 32,
                  ),
                );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: latest.backgroundColor ?? widget.theme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.theme.textColor.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: canvasContent,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          latest.type == NoteitType.text ? 'Shared Text Note 📝' : previewText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.heading(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: widget.theme.textColor.withValues(alpha: 0.95),
          ),
        ),
      ],
    );
  }
}
