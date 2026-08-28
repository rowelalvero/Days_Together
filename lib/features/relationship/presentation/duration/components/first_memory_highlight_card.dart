import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:days_together/features/timeline/timeline_state.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/shared/storage_image.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Bento card highlighting the first recorded relationship memory ("How It All Started").
class FirstMemoryHighlightCard extends StatelessWidget {
  final TimelineState tp;
  final LoveStoryTheme theme;

  const FirstMemoryHighlightCard({
    super.key,
    required this.tp,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final memories = tp.items;
    TimelineItemData? firstMemory;

    if (memories.isNotEmpty) {
      final sorted = List<TimelineItemData>.from(memories)
        ..sort((a, b) => a.date.compareTo(b.date));
      firstMemory = sorted.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bookmark_rounded, color: theme.accentColor, size: 16),
            const SizedBox(width: 8),
            Text(
              'How It All Started',
              style: AppTypography.title(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (firstMemory != null)
          _buildMemoryCard(firstMemory, theme)
        else
          GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: 24,
            width: double.infinity,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.favorite_rounded, color: theme.accentColor, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your story begins here... ❤️',
                  style: AppTypography.bodyLarge(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Capture your first milestone or photo in the Timeline to highlight it here.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMemoryCard(TimelineItemData memory, LoveStoryTheme theme) {
    final formattedDate = DateFormat('MMMM dd, yyyy').format(memory.date);
    final photoUrl = memory.networkImageUrl ??
        (memory.photoUrls.isNotEmpty ? memory.photoUrls.first : null);
    final localPath = memory.imagePath;

    Widget? imageWidget;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      imageWidget = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: StorageImage(
          bucket: StorageBuckets.timeline,
          storageRef: photoUrl,
          localPath: localPath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 180,
          errorWidget: (context) => Container(
            color: theme.textColor.withValues(alpha: 0.05),
            height: 180,
            child: Icon(
              Icons.broken_image_rounded,
              color: theme.textColor.withValues(alpha: 0.2),
              size: 36,
            ),
          ),
        ),
      );
    } else if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        imageWidget = ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 180,
          ),
        );
      }
    }

    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageWidget != null) imageWidget,
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'FIRST CAPTURED MEMORY',
                        style: AppTypography.cardCategory(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: theme.accentColor,
                        ),
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: AppTypography.caption(
                        fontSize: 11,
                        color: theme.textColor.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  memory.title.isNotEmpty ? memory.title : 'Our First Day Together',
                  style: AppTypography.title(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                if (memory.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    memory.description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(
                      fontSize: 12.5,
                      color: theme.textColor.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
