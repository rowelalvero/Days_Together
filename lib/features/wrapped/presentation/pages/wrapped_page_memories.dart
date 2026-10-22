import 'package:flutter/material.dart';
import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_animated_counter.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_empty_memories_state.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_featured_memory_card.dart';

/// Its inline featured-memory card and empty state were extracted into
/// widgets under `presentation/widgets/` (Migration audit item 6).
class WrappedPageMemories extends StatelessWidget {
  final WrappedData data;
  const WrappedPageMemories({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(36, 24, 36, 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Headline count
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Text(
                'You created',
                style: AppTypography.cormorant(
                  fontSize: 26,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 12),
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [
                  Color(0xFFE040FB),
                  Color(0xFFEA80FC),
                  Color(0xFFCE93D8),
                ],
              ).createShader(b),
              child: WrappedAnimatedCounter(
                endValue: data.memoriesThisYear.toDouble(),
                duration: const Duration(milliseconds: 1600),
                style: AppTypography.display(
                  fontSize: 88,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Text(
                data.memoriesThisYear == 1
                    ? 'new memory in ${data.year}'
                    : 'new memories in ${data.year}',
                style: AppTypography.cormorant(
                  fontSize: 26,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            // Featured memory card
            if (data.featuredMemoryTitle?.isNotEmpty ?? false)
              WrappedFeaturedMemoryCard(data: data)
            else
              const WrappedEmptyMemoriesState(),
            const SizedBox(height: 24),
            if (data.totalMemories > 0)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOut,
                builder: (_, v, child) => Opacity(opacity: v, child: child),
                child: Text(
                  '${data.totalMemories} memories in your timeline total 📸',
                  style: AppTypography.body(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
