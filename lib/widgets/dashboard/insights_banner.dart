import 'dart:async';
import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';

class InsightsBanner extends StatefulWidget {
  final TimelineProvider timelineProvider;
  final BucketListProvider bucketProvider;
  final RelationshipProvider relationshipProvider;
  final dynamic theme;

  const InsightsBanner({
    super.key,
    required this.timelineProvider,
    required this.bucketProvider,
    required this.relationshipProvider,
    required this.theme,
  });

  @override
  State<InsightsBanner> createState() => _InsightsBannerState();
}

class _InsightsBannerState extends State<InsightsBanner> {
  int _index = 0;
  Timer? _timer;
  List<String> _insights = [];

  @override
  void initState() {
    super.initState();
    _generateInsights();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && _insights.isNotEmpty) {
        setState(() {
          _index = (_index + 1) % _insights.length;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant InsightsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _generateInsights();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _generateInsights() {
    final memCount = widget.timelineProvider.timelineItems.length;
    final bucketPercent = widget.bucketProvider.progress * 100;
    final years = widget.relationshipProvider.years;
    final partnerName = widget.relationshipProvider.partnerName ?? 'Partner';
    final isOnline = widget.relationshipProvider.isPartnerOnline;

    _insights = [
      '💖 You created $memCount memories together.',
      '📅 Your relationship timeline is $years years strong.',
      '📈 You completed ${bucketPercent.toStringAsFixed(0)}% of your bucket list items.',
      if (isOnline)
        '⏰ $partnerName is active right now. Send a love touch! 💌'
      else
        '💡 Tip: Check out Doodle Notes or Topic Cards for a late-night chat.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_insights.isEmpty) return const SizedBox.shrink();

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.pinkAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.pinkAccent, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RELATIONSHIP INSIGHTS',
                  style: AppTypography.caption(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.pinkAccent).copyWith(letterSpacing: 1),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _insights[_index],
                    key: ValueKey(_insights[_index]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLarge(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.theme.textColor.withValues(alpha: 0.9),),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
              icon: Icon(Icons.chevron_left_rounded, color: widget.theme.textColor.withValues(alpha: 0.3), size: 18),
            onPressed: () {
              setState(() {
                _index = (_index - 1 + _insights.length) % _insights.length;
              });
            },
          ),
          IconButton(
              icon: Icon(Icons.chevron_right_rounded, color: widget.theme.textColor.withValues(alpha: 0.3), size: 18),
            onPressed: () {
              setState(() {
                _index = (_index + 1) % _insights.length;
              });
            },
          ),
        ],
      ),
    );
  }
}
