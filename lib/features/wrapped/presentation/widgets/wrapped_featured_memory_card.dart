import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/core/storage/storage_url_service.dart';
import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_empty_image_box.dart';
import 'package:days_together/shared/widgets/storage_image.dart';

/// The featured-memory image/title/description card on
/// [WrappedPageMemories]. Extracted from its inline `build()` (Migration
/// audit item 6).
class WrappedFeaturedMemoryCard extends StatelessWidget {
  const WrappedFeaturedMemoryCard({super.key, required this.data});

  final WrappedData data;

  @override
  Widget build(BuildContext context) {
    final hasImage = data.hasFeaturedImage;
    final imageUrl = data.featuredMemoryImageUrl;
    final imagePath = data.featuredMemoryImagePath;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(
        scale: 0.85 + 0.15 * v,
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: imageUrl != null
                        ? StorageImage(
                            bucket: StorageBuckets.timeline,
                            storageRef: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context) =>
                                Container(color: Colors.white10),
                            errorWidget: (context) =>
                                const WrappedEmptyImageBox(),
                          )
                        : imagePath != null
                        ? Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const WrappedEmptyImageBox(),
                          )
                        : const WrappedEmptyImageBox(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.featuredMemoryDate != null)
                      Text(
                        DateFormat('MMM d, y').format(data.featuredMemoryDate!),
                        style: AppTypography.caption(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w500,
                        ).copyWith(letterSpacing: 0.5),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      data.featuredMemoryTitle!,
                      style: AppTypography.heading(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (data.featuredMemoryDescription?.isNotEmpty ??
                        false) ...[
                      const SizedBox(height: 8),
                      Text(
                        data.featuredMemoryDescription!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
