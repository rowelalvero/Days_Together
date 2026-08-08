import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:days_together/screens/wrapped/wrapped_data.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/widgets/wrapped/wrapped_animated_counter.dart';

class WrappedPageMemories extends StatelessWidget {
  final WrappedData data;
  const WrappedPageMemories({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final hasImage = data.hasFeaturedImage;
    final imageUrl = data.featuredMemoryImageUrl;
    final imagePath = data.featuredMemoryImagePath;

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
                colors: [Color(0xFFE040FB), Color(0xFFEA80FC), Color(0xFFCE93D8)],
              ).createShader(b),
              child: WrappedAnimatedCounter(
                endValue: data.memoriesThisYear.toDouble(),
                duration: const Duration(milliseconds: 1600),
                style: AppTypography.mainCounter(
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
              TweenAnimationBuilder<double>(
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
                                top: Radius.circular(24)),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                          color: Colors.white10),
                                      errorWidget: (context, url, error) =>
                                          _emptyImageBox(),
                                    )
                                  : imagePath != null
                                      ? Image.asset(
                                          imagePath,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) => _emptyImageBox(),
                                        )
                                      : _emptyImageBox(),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data.featuredMemoryDate != null)
                                Text(
                                  DateFormat('MMM d, y')
                                      .format(data.featuredMemoryDate!),
                                  style: AppTypography.caption(
                                    fontSize: 11,
                                    color:
                                        Colors.white.withValues(alpha: 0.45),
                                    fontWeight: FontWeight.w500,
                                  ).copyWith(letterSpacing: 0.5),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                data.featuredMemoryTitle!,
                                style: AppTypography.sectionHeader(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (data.featuredMemoryDescription
                                      ?.isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 8),
                                Text(
                                  data.featuredMemoryDescription!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body(
                                    fontSize: 13,
                                    color:
                                        Colors.white.withValues(alpha: 0.6),
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
              )
            else
              _emptyMemoriesState(),
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

  Widget _emptyImageBox() => Container(
        color: Colors.white10,
        child: const Center(
          child: Icon(Icons.image_rounded, color: Colors.white24, size: 40),
        ),
      );

  Widget _emptyMemoriesState() => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1000),
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              const Text('📷', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                'Your story starts here',
                style: AppTypography.sectionHeader(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Add memories to your timeline\nand they\'ll live here next year.',
                style: AppTypography.body(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.55),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
