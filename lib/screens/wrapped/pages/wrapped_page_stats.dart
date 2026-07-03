import 'package:flutter/material.dart';
import 'package:days_together/screens/wrapped/wrapped_data.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/widgets/wrapped/wrapped_animated_counter.dart';

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
              builder: (_, v, c) => Opacity(opacity: v, child: c),
              child: Text(
                'Your Year in Numbers',
                style: AppTypography.mainCounter(
                  fontSize: 30,
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
              builder: (_, v, c) => Opacity(opacity: v, child: c),
              child: Text(
                '${data.year} at a glance',
                style: AppTypography.cormorant(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w400,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 36),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: stats.length,
              itemBuilder: (context, i) {
                final s = stats[i];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 600 + i * 100),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Transform.translate(
                    offset: Offset(0, 20 * (1 - v)),
                    child: Opacity(opacity: v, child: child),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.emoji,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 6),
                        WrappedAnimatedCounter(
                          endValue: s.value,
                          duration: Duration(milliseconds: 1000 + i * 80),
                          style: AppTypography.mainCounter(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.label,
                          style: AppTypography.caption(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
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
