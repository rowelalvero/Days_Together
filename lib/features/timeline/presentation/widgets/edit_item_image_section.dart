import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/core/storage/storage_url_service.dart';
import 'package:days_together/features/timeline/presentation/widgets/memory_hero_image.dart';
import 'package:days_together/shared/widgets/glass_container.dart';
import 'package:days_together/shared/widgets/storage_image.dart';

/// The tappable "change photo" image preview in [EditItemDialog]. Extracted
/// from its `_buildImageSection` (Migration audit item 6).
class EditItemImageSection extends StatelessWidget {
  const EditItemImageSection({
    super.key,
    required this.theme,
    required this.networkImageUrl,
    required this.localPath,
    required this.onTap,
  });

  final LoveStoryTheme theme;
  final String? networkImageUrl;

  /// A freshly picked image path wins over whatever is stored.
  final String? localPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        height: 200,
        width: double.infinity,
        borderRadius: 28,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: StorageImageBuilder(
                  bucket: StorageBuckets.timeline,
                  storageRef: networkImageUrl,
                  localPath: localPath,
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
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black26,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Change Photo',
                    style: AppTypography.bodyLarge(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
