import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
              const Icon(Icons.auto_awesome, color: Colors.pinkAccent, size: 14),
              const SizedBox(width: 6),
              Text(
                'LOVED WITHOUT LIMITS SINCE ${startDate.year}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.pinkAccent,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Large Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                NumberFormat('#,###').format(totalDays),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 54,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.pinkAccent, Colors.amberAccent],
                ).createShader(bounds),
                child: Text(
                  'Days',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Ticking stopwatch horizontal bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
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
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time_filled_rounded, color: Colors.pinkAccent, size: 14),
              const SizedBox(width: 6),
              Text(
                'Co-Synched Clock live counter updating frame state...',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white54,
                ),
              ),
            ],
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
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white30,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
