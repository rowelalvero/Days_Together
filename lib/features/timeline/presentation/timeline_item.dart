import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/screens/timeline/memory_detail_screen.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/widgets/storage_image.dart';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';

import 'package:intl/intl.dart';

/// Shown while a memory's image is resolving, or when it has none.
const AssetImage _kTimelineFallbackImage =
    AssetImage('assets/images/app_icon.png');

class TimelineItemWidget extends StatefulWidget {
  final TimelineItemData item;
  final int index;
  final bool isSelected;

  const TimelineItemWidget({
    super.key,
    required this.item,
    required this.index,
    this.isSelected = false,
  });

  @override
  State<TimelineItemWidget> createState() => _TimelineItemWidgetState();
}

class _TimelineItemWidgetState extends State<TimelineItemWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 400 + (widget.index % 5 * 100)),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    final bool isLeft = widget.index % 2 == 0;

    return FadeTransition(
      opacity: _animationController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic)),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: isLeft
                      ? Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _buildDetailContent(theme, CrossAxisAlignment.end),
                          ),
                        )
                      : _buildGlassCard(theme),
                ),
                _buildCenterPoint(theme),
                Expanded(
                  child: !isLeft
                      ? Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _buildDetailContent(theme, CrossAxisAlignment.start),
                          ),
                        )
                      : _buildGlassCard(theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetailContent(LoveStoryTheme theme, CrossAxisAlignment alignment) {
    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == CrossAxisAlignment.end) ...[
            Text(
              DateFormat('MMM dd, yyyy • h:mm a').format(widget.item.date),
              style: AppTypography.bodyLarge(fontSize: 11, color: theme.accentColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Icon(Icons.access_time_rounded, size: 12, color: theme.accentColor),
          ] else ...[
            Icon(Icons.access_time_rounded, size: 12, color: theme.accentColor),
            const SizedBox(width: 6),
            Text(
              DateFormat('MMM dd, yyyy • h:mm a').format(widget.item.date),
              style: AppTypography.bodyLarge(fontSize: 11, color: theme.accentColor, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
      if (widget.item.location != null && widget.item.location!.isNotEmpty) ...[
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alignment == CrossAxisAlignment.end) ...[
              Flexible(
                child: Text(
                  widget.item.location!,
                  style: AppTypography.bodyMedium(fontSize: 11, color: theme.textColor.withValues(alpha: 0.7)),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.location_on_rounded, size: 12, color: theme.textColor.withValues(alpha: 0.7)),
            ] else ...[
              Icon(Icons.location_on_rounded, size: 12, color: theme.textColor.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.item.location!,
                  style: AppTypography.bodyMedium(fontSize: 11, color: theme.textColor.withValues(alpha: 0.7)),
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    ];
  }

  Widget _buildCenterPoint(LoveStoryTheme theme) {
    final isSelected = widget.isSelected;
    return SizedBox(
      width: 40,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: isSelected ? 15.0 : 10.0,
          height: isSelected ? 15.0 : 10.0,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.accentColor.withValues(alpha: 0.8),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: theme.accentColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(LoveStoryTheme theme) {
    return OpenContainer(
      transitionType: ContainerTransitionType.fade,
      closedColor: Colors.transparent,
      openColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      closedBuilder: (context, action) => GestureDetector(
        onTap: action,
        child: GlassContainer(
          padding: const EdgeInsets.all(12),
          borderRadius: 24,
          opacity: 0.1,
          child: widget.item.isImageCard ? _buildImageContent(theme) : _buildTextContent(theme),
        ),
      ),
      openBuilder: (context, action) => MemoryDetailScreen(item: widget.item),
    );
  }

  Widget _buildImageContent(LoveStoryTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              StorageImageBuilder(
                bucket: StorageBuckets.timeline,
                storageRef: widget.item.networkImageUrl,
                localPath: widget.item.imagePath,
                builder: (context, image) => Image(
                  image: image ?? _kTimelineFallbackImage,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 120,
                    width: double.infinity,
                    color: theme.textColor.withValues(alpha: 0.1),
                    child: Icon(Icons.broken_image_rounded, color: theme.textColor.withValues(alpha: 0.2)),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GlassContainer(
                  borderRadius: 12,
                  padding: const EdgeInsets.all(6),
                  blur: 5,
                  child: Text(widget.item.mood, style: AppTypography.body(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.item.title,
          style: AppTypography.bodyLarge(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          widget.item.description,
          style: AppTypography.bodyMedium(fontSize: 11, color: theme.textColor.withValues(alpha: 0.6), height: 1.4),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTextContent(LoveStoryTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.item.title,
                style: AppTypography.bodyLarge(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.item.mood, style: AppTypography.body(fontSize: 18)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.item.description,
          style: AppTypography.heading(fontSize: 13, color: theme.textColor.withValues(alpha: 0.7), height: 1.5).copyWith(fontStyle: FontStyle.italic),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

}

