import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/timeline/presentation/widgets/memory_hero_image.dart';
import 'package:days_together/shared/models/timeline_model.dart';

/// [MemoryDetailScreen]'s collapsing app bar: the close/notes/edit actions,
/// and (when the memory has a photo) the darkened hero image behind them.
/// Extracted from the screen's `build()` (Migration audit item 6).
class MemoryDetailSliverAppBar extends StatelessWidget {
  const MemoryDetailSliverAppBar({
    super.key,
    required this.item,
    required this.theme,
    required this.onScrollToNotes,
    required this.onEdit,
  });

  final TimelineItemData item;
  final LoveStoryTheme theme;
  final VoidCallback onScrollToNotes;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imagePath != null || item.networkImageUrl != null;
    return SliverAppBar(
      expandedHeight: hasImage ? 350 : 120,
      pinned: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: theme.textColor),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.rate_review_outlined,
            color: theme.accentColor,
            size: 24,
          ),
          tooltip: 'Notes',
          onPressed: onScrollToNotes,
        ),
        IconButton(
          icon: Icon(
            Icons.edit_note_rounded,
            color: theme.accentColor,
            size: 28,
          ),
          tooltip: 'Edit Memory',
          onPressed: onEdit,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: hasImage
            ? MemoryHeroImage(
                theme: theme,
                networkImageUrl: item.networkImageUrl,
                imagePath: item.imagePath,
              )
            : null,
      ),
    );
  }
}
