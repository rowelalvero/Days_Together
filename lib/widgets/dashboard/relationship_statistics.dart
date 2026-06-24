import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/providers/noteit_provider.dart';
import 'package:days_together/providers/vault_provider.dart';
import 'package:days_together/providers/time_capsule_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';

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
    final noteit = context.watch<NoteitProvider>();
    final vault = context.watch<VaultProvider>();
    final capsule = context.watch<TimeCapsuleProvider>();
    final rp = context.watch<RelationshipProvider>();

    final totalMemories = timeline.timelineItems.length;
    final bucketStats = '${bucket.completedItems}/${bucket.totalItems}';
    final totalNotes = noteit.notes.length;
    final totalVaultItems = vault.allItems.length;
    final totalCapsules = capsule.capsules.length;

    // Calculate timeline years from start date
    final startDate = rp.startDate ?? DateTime.now();
    final daysDiff = DateTime.now().difference(startDate).inDays;
    final timelineYears = (daysDiff / 365.25).toStringAsFixed(1);

    final stats = [
      _StatItem(
        label: 'Total Memories',
        value: '$totalMemories',
        color: const Color(0xFFEC4899), // Pink
      ),
      _StatItem(
        label: 'Total Photos',
        value: '$totalVaultItems',
        color: const Color(0xFF8B5CF6), // Purple
      ),
      _StatItem(
        label: 'Timeline Years',
        value: timelineYears,
        color: const Color(0xFFF59E0B), // Yellow/Amber
      ),
      _StatItem(
        label: 'Bucket Completed',
        value: bucketStats,
        color: const Color(0xFF10B981), // Green
      ),
      _StatItem(
        label: 'Capsules',
        value: '$totalCapsules',
        color: const Color(0xFF06B6D4), // Cyan
      ),
      _StatItem(
        label: 'Shared Notes',
        value: '$totalNotes',
        color: const Color(0xFFEF4444), // Red
      ),
    ];

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Icon(
                  Icons.show_chart_rounded,
                  color: Color(0xFFEC4899),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Synced Relationship',
                      style: AppTypography.caption(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                    ),
                    Text(
                      'Statistics',
                      style: AppTypography.caption(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'METRICS SYNC',
                    style: AppTypography.caption(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white38).copyWith(letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '100%',
                    style: AppTypography.caption(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white38),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              final item = stats[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.value,
                      style: AppTypography.caption(fontSize: 26, fontWeight: FontWeight.w800, color: item.color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: AppTypography.caption(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });
}
