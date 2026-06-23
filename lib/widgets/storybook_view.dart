import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/widgets/comments_sidebar.dart';

class StorybookView extends StatefulWidget {
  final List<TimelineItemData> items;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;

  const StorybookView({
    super.key,
    required this.items,
    required this.pageController,
    required this.onPageChanged,
  });

  @override
  State<StorybookView> createState() => _StorybookViewState();
}

class _StorybookViewState extends State<StorybookView> {
  double _currentPageValue = 0.0;

  @override
  void initState() {
    super.initState();
    widget.pageController.addListener(_pageScrollListener);
    // Set initial page value if controller already has a value
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.pageController.hasClients) {
        setState(() {
          _currentPageValue = widget.pageController.page ?? 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_pageScrollListener);
    super.dispose();
  }

  void _pageScrollListener() {
    if (mounted && widget.pageController.hasClients) {
      setState(() {
        _currentPageValue = widget.pageController.page ?? 0.0;
      });
    }
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
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          'No chapters written yet.',
          style: GoogleFonts.inter(color: Colors.white30, fontSize: 16),
        ),
      );
    }

    return PageView.builder(
      controller: widget.pageController,
      onPageChanged: widget.onPageChanged,
      itemCount: widget.items.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final hasImage = item.imagePath != null || item.networkImageUrl != null;

        // Calculate card scale and translation offset for tactile transition
        double difference = index - _currentPageValue;
        double scale = 1.0 - (difference.abs() * 0.15).clamp(0.0, 0.15);
        double rotation = (difference * -0.05).clamp(-0.05, 0.05);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Immersive blurred background
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: hasImage
                    ? Container(
                        key: ValueKey(item.id),
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: _getImageProvider(item),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      )
                    : Container(
                        key: ValueKey(item.id),
                        decoration: BoxDecoration(
                          gradient: themeProvider.currentGradient,
                        ),
                      ),
              ),
            ),

            // Tactile Floating Card
            Center(
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: GlassContainer(
                      width: double.infinity,
                      height: 480,
                      borderRadius: 30,
                      opacity: 0.1,
                      blur: 20,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top details (Mood / Date / Edit)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GlassContainer(
                                borderRadius: 16,
                                padding: const EdgeInsets.all(10),
                                blur: 5,
                                child: Text(
                                  item.mood,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    DateFormat('MMMM dd, yyyy').format(item.date),
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    DateFormat.jm().format(item.date),
                                    style: GoogleFonts.inter(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Image thumbnail if exists
                          if (hasImage) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image(
                                image: _getImageProvider(item),
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Title and location
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (item.location != null && item.location!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 13, color: Colors.white54),
                                const SizedBox(width: 4),
                                Text(
                                  item.location!,
                                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Description
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                item.description,
                                style: GoogleFonts.lora(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  height: 1.6,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Comment Count Badge / Action
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => CommentsSidebar.show(context, item),
                              child: GlassContainer(
                                borderRadius: 20,
                                opacity: 0.15,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 16,
                                      color: theme.accentColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${item.comments.length}',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'chats',
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
