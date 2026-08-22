import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:days_together/screens/wrapped/wrapped_data.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/widgets/storage_image.dart';

/// Page 12 — full-bleed immersive featured memory image.
class WrappedPageFeaturedMemory extends StatelessWidget {
  final WrappedData data;
  const WrappedPageFeaturedMemory({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final hasImage = data.hasFeaturedImage;
    final imageUrl = data.featuredMemoryImageUrl;
    final imagePath = data.featuredMemoryImagePath;
    final hasTitle = data.featuredMemoryTitle?.isNotEmpty ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed image or gradient placeholder
        if (hasImage)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.08, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOut,
            builder: (_, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: imageUrl != null
                ? StorageImage(
                    bucket: StorageBuckets.timeline,
                    storageRef: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context) =>
                        Container(color: const Color(0xFF1c1c2e)),
                    errorWidget: (context) => _gradientFallback(context),
                  )
                : imagePath != null
                    ? Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _gradientFallback(context),
                      )
                    : _gradientFallback(context),
          )
        else
          _gradientFallback(context),
        // Dark gradient overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.3, 0.6, 1.0],
              ),
            ),
          ),
        ),
        // Text overlay at bottom
        Positioned(
          left: 32,
          right: 32,
          bottom: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (_, v, c) => Opacity(opacity: v, child: c),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '⭐ Featured Memory',
                    style: AppTypography.caption(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ).copyWith(letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (hasTitle)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOut,
                  builder: (_, v, child) => Transform.translate(
                    offset: Offset(0, 16 * (1 - v)),
                    child: Opacity(opacity: v, child: child),
                  ),
                  child: Text(
                    data.featuredMemoryTitle!,
                    style: AppTypography.heading(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (data.featuredMemoryDate != null) ...[
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1100),
                  builder: (_, v, c) => Opacity(opacity: v, child: c),
                  child: Text(
                    DateFormat('MMMM d, y')
                        .format(data.featuredMemoryDate!),
                    style: AppTypography.body(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
              if (data.featuredMemoryDescription?.isNotEmpty ?? false) ...[
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1200),
                  builder: (_, v, c) => Opacity(opacity: v, child: c),
                  child: Text(
                    data.featuredMemoryDescription!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.75),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _gradientFallback(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1c1c2e), Color(0xFF2d2d44), Color(0xFF1c1c2e)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📷', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 20),
              Text(
                'Your most beautiful memory',
                style: AppTypography.heading(
                  fontSize: 22,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Add photos to your memories\nand watch this page transform.',
                  style: AppTypography.body(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
}
