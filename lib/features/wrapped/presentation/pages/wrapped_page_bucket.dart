import 'package:flutter/material.dart';
import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_bucket_completed_card.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_bucket_empty_state.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_bucket_progress_bar.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_favorite_bucket_item_card.dart';

/// Its inline progress bar, completed-this-year card, favorite-item
/// card, and empty state were extracted into widgets under
/// `presentation/widgets/` (Migration audit item 6).
class WrappedPageBucket extends StatelessWidget {
  final WrappedData data;
  const WrappedPageBucket({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final hasBucket = data.bucketTotal > 0;
    final progress = hasBucket ? data.bucketCompleted / data.bucketTotal : 0.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: const Text('🪣', style: TextStyle(fontSize: 56)),
            ),
            const SizedBox(height: 20),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Text(
                'Bucket List',
                style: AppTypography.display(
                  fontSize: 38,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Text(
                'Dreams achieved together',
                style: AppTypography.cormorant(
                  fontSize: 20,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 40),
            if (hasBucket) ...[
              WrappedBucketProgressBar(
                progress: progress,
                completed: data.bucketCompleted,
                total: data.bucketTotal,
              ),
              const SizedBox(height: 32),
              WrappedBucketCompletedCard(
                completedThisYear: data.bucketCompletedThisYear,
                year: data.year,
              ),
              if (data.favoriteBucketItem?.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                WrappedFavoriteBucketItemCard(item: data.favoriteBucketItem!),
              ],
            ] else
              const WrappedBucketEmptyState(),
          ],
        ),
      ),
    );
  }
}
