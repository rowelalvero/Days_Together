import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_share_chip.dart';

/// The shareable summary card rendered inside [WrappedPageFinale]'s
/// off-screen `RepaintBoundary`. Extracted from its `_buildShareCard`
/// method (Migration audit item 6).
class WrappedShareCard extends StatelessWidget {
  const WrappedShareCard({super.key, required this.data});

  final WrappedData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a0033), Color(0xFF3d0066), Color(0xFF0a001a)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('❤️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                'Days Together',
                style: AppTypography.body(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Wrapped ${data.year}',
                style: AppTypography.caption(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                ).copyWith(letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${data.yourName} & ${data.partnerDisplayName}',
            style: AppTypography.heading(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              WrappedShareChip(
                text: '${NumberFormat('#,###').format(data.totalDays)} Days',
                emoji: '❤️',
              ),
              const SizedBox(width: 10),
              WrappedShareChip(
                text: '${data.totalMemories} Memories',
                emoji: '📸',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              WrappedShareChip(text: '${data.totalNotes} Notes', emoji: '💌'),
              const SizedBox(width: 10),
              WrappedShareChip(
                text: '${data.bucketCompleted} Goals',
                emoji: '🪣',
              ),
            ],
          ),
          if (data.startDate != null) ...[
            const SizedBox(height: 16),
            Text(
              'Together since ${DateFormat('MMM d, y').format(data.startDate!)}',
              style: AppTypography.body(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
