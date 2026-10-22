import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/core/models/paging_status.dart';

/// How close (in logical pixels) to the end of a scrollable a paged list
/// starts fetching its next page -- early enough that the next items are
/// usually there before the user reaches them.
const double kPagingScrollThreshold = 600;

/// True when [metrics] is within [kPagingScrollThreshold] of the end the
/// list grows towards. For a `reverse: true` list (chat) that end is the
/// top of the screen, which is still `extentAfter`.
bool isNearScrollEnd(ScrollMetrics metrics) =>
    metrics.extentAfter < kPagingScrollThreshold;

/// The tail of a paged list: a spinner while a page loads, a retry button
/// after a failure, an optional end-of-list note once everything is loaded,
/// and nothing otherwise.
class PagedListFooter extends StatelessWidget {
  const PagedListFooter({
    super.key,
    required this.status,
    required this.onRetry,
    required this.color,
    this.endLabel,
  });

  final PagingStatus status;
  final VoidCallback onRetry;
  final Color color;

  /// Shown once the list is exhausted; null shows nothing.
  final String? endLabel;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (status.isLoadingMore) {
      child = SizedBox.square(
        key: const ValueKey('paged-footer-loading'),
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    } else if (status.loadMoreFailed) {
      child = Column(
        key: const ValueKey('paged-footer-error'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Couldn't load more",
            style: AppTypography.body(
              color: color.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Try again',
              style: AppTypography.body(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    } else if (!status.hasMore && endLabel != null) {
      child = Text(
        endLabel!,
        key: const ValueKey('paged-footer-end'),
        style: AppTypography.body(
          color: color.withValues(alpha: 0.5),
          fontSize: 13,
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: child),
    );
  }
}
