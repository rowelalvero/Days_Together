import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';
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

  int _getTargetDaysForMilestone(MilestoneInfo milestone, DateTime? startDate) {
    final title = milestone.title;
    if (title.contains('Anniversary') && startDate != null) {
      final numMatch = RegExp(r'\d+').firstMatch(title);
      if (numMatch != null) {
        final year = int.tryParse(numMatch.group(0)!) ?? 1;
        final anniversaryDate = DateTime(
          startDate.year + year,
          startDate.month,
          startDate.day,
        );
        return anniversaryDate.difference(startDate).inDays;
      }
    }
    final numMatch = RegExp(r'\d+').firstMatch(title);
    if (numMatch != null) {
      return int.tryParse(numMatch.group(0)!) ?? 100;
    }
    return 100;
  }

  @override
  Widget build(BuildContext context) {
    final rawMilestones = widget.relationshipProvider.nextMilestones;
    final startDate = widget.relationshipProvider.startDate;
    final daysTogether = widget.relationshipProvider.totalDays;

    // Ensure we always have milestones to show, fallback to mock data if empty
    final milestones = rawMilestones.isNotEmpty
        ? rawMilestones
        : [
            const MilestoneInfo(title: '1500 Days', daysUntil: 265, progress: 0.82),
            const MilestoneInfo(title: '2000 Days', daysUntil: 765, progress: 0.62),
            const MilestoneInfo(title: '5th Anniversary', daysUntil: 591, progress: 0.70),
          ];

    // Safely clamp selection index if the milestones list size changes
    final selectedIndex = _selectedMilestoneIndex.clamp(0, milestones.length - 1);
    final milestone = milestones[selectedIndex];

    final targetDays = _getTargetDaysForMilestone(milestone, startDate);
    final isAnniversary = milestone.title.contains('Anniversary');

    final milestoneHeadingText = isAnniversary
        ? milestone.title
        : '${NumberFormat('#,###').format(targetDays)} Days Together';

    // Show up to 3 segments in the selector capsule
    final visibleSegmentCount = milestones.length < 3 ? milestones.length : 3;

    // Calculations based on day 0 to the milestone target days
    final isCompleted = daysTogether >= targetDays;
    final progress = targetDays > 0 
        ? (daysTogether / targetDays).clamp(0.0, 1.0) 
        : 0.0;
    final percentComplete = (progress * 100).round();
    final daysRemaining = isCompleted ? 0 : targetDays - daysTogether;

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
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
                  // Custom compass logo
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.theme.accentColor,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: 0.785398, // Rotate 45 degrees
                        child: Icon(
                          Icons.navigation_rounded,
                          color: widget.theme.accentColor,
                          size: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Next Milestone',
                    style: AppTypography.bodyLarge(fontSize: 14, fontWeight: FontWeight.w600, color: widget.theme.textColor.withValues(alpha: 0.95)),
                  ),
                ],
              ),
              // Segmented Tab Selector Capsule
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: widget.theme.textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.theme.textColor.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(visibleSegmentCount, (index) {
                    final item = milestones[index];
                    final target = _getTargetDaysForMilestone(item, startDate);
                    final isSelected = selectedIndex == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMilestoneIndex = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.theme.textColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$target',
                          style: AppTypography.button(fontSize: 10.5, fontWeight: FontWeight.w700, color: isSelected 
                                ? widget.theme.textColor 
                                : widget.theme.textColor.withValues(alpha: 0.3)),
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
                      style: AppTypography.sectionHeader(fontSize: 20, fontWeight: FontWeight.w700, color: widget.theme.textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (isCompleted)
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Milestone Achieved! 🎉',
                            style: AppTypography.body(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                          ),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            NumberFormat('#,###').format(daysRemaining),
                            style: AppTypography.sectionHeader(fontSize: 24, fontWeight: FontWeight.w700, color: widget.theme.textColor.withValues(alpha: 0.9)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'days remain',
                            style: AppTypography.body(fontSize: 12, color: widget.theme.textColor.withValues(alpha: 0.4), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Target: ${NumberFormat('#,###').format(targetDays)} days total',
                      style: AppTypography.caption(fontSize: 10, color: widget.theme.textColor.withValues(alpha: 0.4), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Progress Ring Stack
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      backgroundColor: widget.theme.textColor.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCompleted ? const Color(0xFF10B981) : const Color(0xFFF43F5E), // Rose Accent
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percentComplete%',
                        style: AppTypography.body(fontSize: 15, fontWeight: FontWeight.w800, color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF43F5E)),
                      ),
                      Text(
                        'DONE',
                        style: AppTypography.body(fontSize: 8, fontWeight: FontWeight.w800, color: widget.theme.textColor.withValues(alpha: 0.3)).copyWith(letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Divider(
            color: widget.theme.textColor.withValues(alpha: 0.1),
            height: 32,
            thickness: 1,
          ),
          // Sparkle Footer Message
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF43F5E), // Pink/Green Sparkle
                size: 13,
              ),
              const SizedBox(width: 8),
              Text(
                isCompleted 
                    ? 'A grand celebration awaits!' 
                    : 'You are $percentComplete% of the way there',
                style: AppTypography.button(fontSize: 10.5, color: widget.theme.textColor.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
