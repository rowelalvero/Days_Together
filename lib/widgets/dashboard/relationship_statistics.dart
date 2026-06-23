import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/providers/calendar_provider.dart';
import 'package:days_together/providers/noteit_provider.dart';
import 'package:days_together/providers/vault_provider.dart';
import 'package:days_together/providers/time_capsule_provider.dart';

class RelationshipStatistics extends StatelessWidget {
  final dynamic theme;

  const RelationshipStatistics({
    super.key,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final timeline = context.watch<TimelineProvider>();
    final bucket = context.watch<BucketListProvider>();
    final calendar = context.watch<CalendarProvider>();
    final noteit = context.watch<NoteitProvider>();
    final vault = context.watch<VaultProvider>();
    final capsule = context.watch<TimeCapsuleProvider>();

    final totalMemories = timeline.timelineItems.length;
    final bucketStats = '${bucket.completedItems}/${bucket.totalItems}';
    final totalEvents = calendar.events.length;
    final totalNotes = noteit.notes.length;
    final totalVaultItems = vault.allItems.length;
    final totalCapsules = capsule.capsules.length;

    final stats = [
      _StatItem(
        label: 'Memories Created',
        value: '$totalMemories',
        icon: Icons.photo_library_rounded,
        color: Colors.pinkAccent,
      ),
      _StatItem(
        label: 'Bucket List Done',
        value: bucketStats,
        icon: Icons.assignment_turned_in_rounded,
        color: Colors.amberAccent,
      ),
      _StatItem(
        label: 'Calendar Events',
        value: '$totalEvents',
        icon: Icons.event_rounded,
        color: Colors.blueAccent,
      ),
      _StatItem(
        label: 'Love Notes',
        value: '$totalNotes',
        icon: Icons.favorite_rounded,
        color: Colors.redAccent,
      ),
      _StatItem(
        label: 'Secret Vault',
        value: '$totalVaultItems',
        icon: Icons.lock_rounded,
        color: Colors.purpleAccent,
      ),
      _StatItem(
        label: 'Time Capsules',
        value: '$totalCapsules',
        icon: Icons.hourglass_bottom_rounded,
        color: Colors.tealAccent,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Synced Statistics',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'SYNCED',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final item = stats[index];
            return GlassContainer(
              padding: const EdgeInsets.all(12),
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54,
                        ),
                      ),
                      Icon(item.icon, color: item.color, size: 16),
                    ],
                  ),
                  Text(
                    item.value,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
