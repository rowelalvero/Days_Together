import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/providers/relationship_provider.dart';

class MilestoneCard extends StatelessWidget {
  final RelationshipProvider relationshipProvider;
  final dynamic theme;

  const MilestoneCard({
    super.key,
    required this.relationshipProvider,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final milestones = relationshipProvider.nextMilestones;
    
    // If no upcoming milestones, create a default mockup milestone or empty state
    final milestone = milestones.isNotEmpty 
        ? milestones.first 
        : const MilestoneInfo(title: 'Next Anniversary', daysUntil: 365, progress: 0.0);

    final title = milestone.title;
    final progress = milestone.progress;
    final daysUntil = milestone.daysUntil;
    final percentText = '${(progress * 100).toStringAsFixed(0)}%';

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
              Text(
                'NEXT MILESTONE',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: theme.accentColor,
                  letterSpacing: 1.5,
                ),
              ),
              const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Circular Progress Indicator
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4.5,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
                    ),
                  ),
                  const Icon(
                    Icons.favorite,
                    color: Colors.pinkAccent,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Text details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      daysUntil > 0 
                          ? '$daysUntil days remaining' 
                          : 'Happening today!',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROGRESS',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                percentText,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: theme.accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
