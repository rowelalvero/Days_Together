import 'dart:io';

import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/core/storage/storage_url_service.dart';
import 'package:days_together/shared/models/noteit_model.dart';
import 'package:days_together/shared/widgets/scale_drawing_painter.dart';
import 'package:days_together/shared/widgets/storage_image.dart';

/// The enlarged view of a scrapbook-mirror chat message, opened by tapping
/// its bubble on [LoveChatScreen]. Extracted from the screen's
/// `_showEnlargeNoteDialog`/`_buildWidgetContent` (Migration audit item 6).
///
/// Shown directly as a `showDialog` builder, matching this app's other
/// dialogs -- no `.show()` static helper.
class EnlargedNoteDialog extends StatelessWidget {
  const EnlargedNoteDialog({
    super.key,
    required this.item,
    required this.theme,
  });

  final NoteitItem item;
  final LoveStoryTheme theme;

  Widget _content() {
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
        errorWidget: (context) =>
            const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    }

    if (item.type == NoteitType.drawing) {
      return CustomPaint(
        painter: ScaleDrawingPainter(
          colorfulStrokes: NoteitItem.deserializeColorfulStrokes(
            item.content,
            theme.textColor,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
              child: _content(),
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
    );
  }
}
