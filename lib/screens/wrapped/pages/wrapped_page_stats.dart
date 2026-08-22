import 'package:flutter/material.dart';
import 'package:days_together/screens/wrapped/wrapped_data.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/features/wrapped/presentation/wrapped_animated_counter.dart';

class WrappedPageStats extends StatelessWidget {
  final WrappedData data;
  const WrappedPageStats({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _Stat('❤️', 'Days Together', data.totalDays.toDouble()),
      _Stat('📸', 'Memories', data.totalMemories.toDouble()),
      _Stat('💌', 'Love Notes', data.totalNotes.toDouble()),
      _Stat('🪣', 'Bucket Goals', data.bucketCompleted.toDouble()),
      _Stat('🖼️', 'Photos', data.totalPhotos.toDouble()),
      _Stat('🎁', 'Time Capsules', data.totalCapsules.toDouble()),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              builder: (context, v, child) =>
                  Opacity(opacity: v, child: child),
              child: Text(
                'Your Year in Numbers',
                style: AppTypography.display(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              builder: (context, v, child) =>
                  Opacity(opacity: v, child: child),
              child: Text(
                '${data.year} at a glance',
                style: AppTypography.cormorant(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 28),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                // 1.55 gives tiles enough height to hold emoji + counter + label
                childAspectRatio: 1.55,
              ),
              itemCount: stats.length,
              itemBuilder: (context, i) {
                final s = stats[i];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 550 + i * 100),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, child) => Transform.translate(
                    offset: Offset(0, 18 * (1 - v)),
                    child: Opacity(opacity: v, child: child),
                  ),
                  // Extract tile to its own widget — avoids competing
                  // ParentData from any ancestor Flex context.
                  child: _StatTile(stat: s, index: i),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Separate StatelessWidget so the tile has its own render subtree,
/// preventing any ParentData bleed from builder closures.
class _StatTile extends StatelessWidget {
  final _Stat stat;
  final int index;
  const _StatTile({required this.stat, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,   // don't force expand
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(stat.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          WrappedAnimatedCounter(
            endValue: stat.value,
            duration: Duration(milliseconds: 900 + index * 80),
            style: AppTypography.display(
              fontSize: 26,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            style: AppTypography.caption(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.45),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Stat {
  final String emoji;
  final String label;
  final double value;
  const _Stat(this.emoji, this.label, this.value);
}
