import 'dart:async';
import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:intl/intl.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/providers/relationship_provider.dart';

class DetailedDaysCounter extends StatefulWidget {
  final RelationshipProvider relationshipProvider;
  final dynamic theme;

  const DetailedDaysCounter({
    super.key,
    required this.relationshipProvider,
    required this.theme,
  });

  @override
  State<DetailedDaysCounter> createState() => _DetailedDaysCounterState();
}

class _DetailedDaysCounterState extends State<DetailedDaysCounter> {
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rp = widget.relationshipProvider;
    final age = rp.preciseAge;
    final totalDays = rp.totalDays;
    final startDate = rp.startDate ?? DateTime.now();

    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      borderRadius: 28,
      child: Column(
        children: [
          // Top Badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Colors.pinkAccent,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'LOVED WITHOUT LIMITS SINCE ${startDate.year}',
                style: AppTypography.captionMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.pinkAccent,
                ).copyWith(letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Large Counter
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [widget.theme.accentColor, Colors.amberAccent],
                ).createShader(bounds),
                child: Text(
                  NumberFormat('#,###').format(totalDays),
                  style: AppTypography.mainCounter(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Days Together',
                style: AppTypography.cormorant(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.theme.textColor.withValues(alpha: 0.8),
                ).copyWith(letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Ticking stopwatch horizontal bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: widget.theme.textColor.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.theme.textColor.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildUnit('Yr', age['years'] ?? 0),
                _buildUnit('Mo', age['months'] ?? 0),
                _buildUnit('Day', age['days'] ?? 0),
                _buildUnit('Hr', age['hours'] ?? 0),
                _buildUnit('Min', age['minutes'] ?? 0),
                _buildUnit('Sec', age['seconds'] ?? 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnit(String label, int val) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            val.toString(),
            style: AppTypography.body(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: widget.theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.body(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: widget.theme.textColor.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
