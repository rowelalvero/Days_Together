import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/providers/relationship_provider.dart';

class MilestoneCard extends StatefulWidget {
  final RelationshipProvider relationshipProvider;
  final dynamic theme;

  const MilestoneCard({
    super.key,
    required this.relationshipProvider,
    required this.theme,
  });

  @override
  State<MilestoneCard> createState() => _MilestoneCardState();
}

class _MilestoneCardState extends State<MilestoneCard> {
  int _selectedMilestoneIndex = 0;

  int _parseTargetDays(String title) {
    if (title.contains('1st Anniversary')) return 365;
    if (title.contains('2nd Anniversary')) return 730;
    if (title.contains('3rd Anniversary')) return 1095;
    if (title.contains('4th Anniversary')) return 1461;
    if (title.contains('5th Anniversary')) return 1826;
    
    final numMatch = RegExp(r'\d+').firstMatch(title);
    if (numMatch != null) {
      return int.tryParse(numMatch.group(0)!) ?? 100;
    }
    return 100;
  }

  @override
  Widget build(BuildContext context) {
    final rawMilestones = widget.relationshipProvider.nextMilestones;
    
    // Ensure we always have milestones to show, even if mocked
    final milestones = rawMilestones.isNotEmpty
        ? rawMilestones
        : [
            const MilestoneInfo(title: '1500 Days', daysUntil: 265, progress: 0.82),
            const MilestoneInfo(title: '2000 Days', daysUntil: 765, progress: 0.62),
            const MilestoneInfo(title: '5th Anniversary', daysUntil: 591, progress: 0.70),
          ];

    // Safely clamp selection index if list changes size
    final selectedIndex = _selectedMilestoneIndex.clamp(0, milestones.length - 1);
    final milestone = milestones[selectedIndex];

    final targetDays = _parseTargetDays(milestone.title);
    final isAnniversary = milestone.title.contains('Anniversary');
    
    final milestoneHeadingText = isAnniversary
        ? milestone.title
        : '${NumberFormat('#,###').format(targetDays)} Days Together';

    // Show up to 3 segments
    final visibleSegmentCount = milestones.length < 3 ? milestones.length : 3;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.explore_rounded,
                    color: Color(0xFF10B981), // Green Accent
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Next Milestone',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              // Segmented Tab Selector Capsule
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(visibleSegmentCount, (index) {
                    final item = milestones[index];
                    final target = _parseTargetDays(item.title);
                    final isSelected = selectedIndex == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMilestoneIndex = index;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '$target',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.white30,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Middle Details & Circular Progress
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestoneHeadingText,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${milestone.daysUntil}',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'days remain',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Target: ${NumberFormat('#,###').format(targetDays)} days total',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white30,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Progress Dial
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: milestone.progress,
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFEC4899), // Pink Accent
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(milestone.progress * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFEC4899),
                        ),
                      ),
                      Text(
                        'DONE',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.white30,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 28),
          // Sparkle Footer Message
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFFEC4899), // Pink Sparkle
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                'You are ${(milestone.progress * 100).toStringAsFixed(0)}% of the way there',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
