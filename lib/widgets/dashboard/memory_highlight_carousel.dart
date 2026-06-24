import 'dart:io';
import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:intl/intl.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/widgets/timeline_item.dart';

class MemoryHighlightCarousel extends StatefulWidget {
  final TimelineProvider timelineProvider;
  final dynamic theme;

  const MemoryHighlightCarousel({
    super.key,
    required this.timelineProvider,
    required this.theme,
  });

  @override
  State<MemoryHighlightCarousel> createState() => _MemoryHighlightCarouselState();
}

class _MemoryHighlightCarouselState extends State<MemoryHighlightCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(TimelineItemData item) {
    final path = item.imagePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) return FileImage(file);
    }
    final url = item.networkImageUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return const AssetImage('assets/images/placeholder.jpg');
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.timelineProvider.timelineItems;
    final theme = widget.theme;

    if (items.isEmpty) {
      return GlassContainer(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        borderRadius: 24,
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome_motion_rounded,
              color: theme.accentColor.withValues(alpha: 0.4),
              size: 44,
            ),
            const SizedBox(height: 16),
            Text(
              'No memories captured yet',
              style: AppTypography.bodyLarge(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Start documenting your milestones and daily stories.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
      );
    }

    // Limit to latest 5 memories for the dashboard highlights
    final displayItems = items.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: displayItems.length,
            itemBuilder: (context, index) {
              final item = displayItems[index];
              final hasImage = item.isImageCard &&
                  ((item.imagePath != null && File(item.imagePath!).existsSync()) ||
                      (item.networkImageUrl != null && item.networkImageUrl!.isNotEmpty));

              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = (_pageController.page! - index);
                    value = (1 - (value.abs() * 0.08)).clamp(0.8, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * 180,
                      width: Curves.easeOut.transform(value) * MediaQuery.of(context).size.width,
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: OpenContainerWrapper(
                    item: item,
                    theme: theme,
                    child: hasImage
                        ? _buildImageCard(item, theme)
                        : _buildTextCard(item, theme),
                  ),
                ),
              );
            },
          ),
        ),
        if (displayItems.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              displayItems.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? theme.accentColor
                      : Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageCard(TimelineItemData item, dynamic theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: DecorationImage(
          image: _getImageProvider(item),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(item.mood, style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 8),
                if (item.location != null && item.location!.isNotEmpty) ...[
                  Icon(Icons.location_on_rounded, size: 12, color: theme.accentColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.location!,
                      style: AppTypography.caption(fontSize: 11, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: AppTypography.caption(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('MMMM dd, yyyy').format(item.date),
              style: AppTypography.caption(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextCard(TimelineItemData item, dynamic theme) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: AppTypography.caption(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(item.mood, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              item.description,
              style: AppTypography.sectionHeader(fontSize: 12, color: Colors.white70, height: 1.4).copyWith(fontStyle: FontStyle.italic),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM dd, yyyy').format(item.date),
                style: AppTypography.caption(fontSize: 10, color: Colors.white38),
              ),
              if (item.location != null && item.location!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_rounded, size: 10, color: theme.accentColor),
                    const SizedBox(width: 3),
                    Text(
                      item.location!,
                      style: AppTypography.caption(fontSize: 10, color: Colors.white38),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class OpenContainerWrapper extends StatelessWidget {
  final TimelineItemData item;
  final dynamic theme;
  final Widget child;

  const OpenContainerWrapper({
    super.key,
    required this.item,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Standard navigation wrapper that doesn't rely on Animations package open_container if it is not suitable,
    // but here we can just use a simple InkWell + Navigator.push to avoid any animation package mismatch.
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MemoryDetailScreen(item: item)),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: child,
    );
  }
}
