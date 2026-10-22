import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/bucket_list/bucket_list_state.dart';

/// The completed-count/progress-bar/percentage card on [BucketListScreen].
/// Extracted from its `_buildProgressCard` (Migration audit item 6).
class BucketListProgressCard extends StatelessWidget {
  const BucketListProgressCard({
    super.key,
    required this.state,
    required this.theme,
  });

  final BucketListState state;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    if (state.totalItems == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.completedItems} of ${state.totalItems} adventures completed',
                  style: AppTypography.body(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 10,
                    backgroundColor: theme.textColor.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: state.progress,
                  strokeWidth: 4,
                  backgroundColor: theme.textColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
                ),
              ),
              Text(
                '${(state.progress * 100).toInt()}%',
                style: AppTypography.caption(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
