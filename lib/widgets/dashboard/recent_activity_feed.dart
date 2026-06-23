import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/providers/timeline_provider.dart';

class RecentActivityFeed extends StatelessWidget {
  final TimelineProvider timelineProvider;
  final dynamic theme;

  const RecentActivityFeed({
    super.key,
    required this.timelineProvider,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final items = timelineProvider.timelineItems;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Take up to 5 items for activity feed
    final feedItems = items.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history_rounded, color: theme.accentColor, size: 16),
            const SizedBox(width: 8),
            Text(
              'Recent Activity Log',
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: feedItems.length,
          itemBuilder: (context, index) {
            final item = feedItems[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: GlassContainer(
                padding: const EdgeInsets.all(12),
                borderRadius: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(item.mood, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.white54,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MM/dd').format(item.date),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
