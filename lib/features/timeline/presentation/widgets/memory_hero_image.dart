import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/core/storage/storage_url_service.dart';
import 'package:days_together/shared/widgets/storage_image.dart';

/// Shown while a memory's image is resolving, or when it has none.
const AssetImage kTimelineFallbackImage = AssetImage(
  'assets/images/app_icon.png',
);

/// The darkened background image behind [MemoryDetailScreen]'s
/// `SliverAppBar`. Extracted from the screen's `build()` (Migration audit
/// item 6).
class MemoryHeroImage extends StatelessWidget {
  const MemoryHeroImage({
    super.key,
    required this.theme,
    required this.networkImageUrl,
    required this.imagePath,
  });

  final LoveStoryTheme theme;
  final String? networkImageUrl;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        StorageImageBuilder(
          bucket: StorageBuckets.timeline,
          storageRef: networkImageUrl,
          localPath: imagePath,
          builder: (context, image, _, _) => Image(
            image: image ?? kTimelineFallbackImage,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: theme.textColor.withValues(alpha: 0.1),
              child: Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  color: theme.textColor.withValues(alpha: 0.2),
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
            ),
          ),
        ),
      ],
    );
  }
}
