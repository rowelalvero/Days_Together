import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/services/date_helper.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/widgets/storage_image.dart';

class RelationshipDurationScreen extends StatelessWidget {
  const RelationshipDurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final rp = context.watch<RelationshipProvider>();
    final tp = context.watch<TimelineProvider>();

    final startDate = rp.startDate ?? DateTime.now();
    final totalDays = rp.totalDays;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor,
              theme.secondaryColor,
              theme.backgroundColor,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Sliver App Bar with Header
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: theme.textColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
                background: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Decorative pulsing circles in background
                    Positioned(
                      top: 40,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite_rounded, color: theme.accentColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'TOGETHER FOR',
                              style: AppTypography.cardCategory(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: theme.textColor.withValues(alpha: 0.6),
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: totalDays.toDouble()),
                          duration: const Duration(milliseconds: 1600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [theme.accentColor, Colors.amberAccent],
                              ).createShader(bounds),
                              child: Text(
                                NumberFormat('#,###').format(value.toInt()),
                                style: AppTypography.mainCounter(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                        Text(
                          'Days',
                          style: AppTypography.cormorant(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor.withValues(alpha: 0.8),
                          ).copyWith(letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.textColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.textColor.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Since ${DateFormat('MMMM dd, yyyy').format(startDate)}',
                            style: AppTypography.bodyMono(
                              fontSize: 11,
                              color: theme.textColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Scrollable Bento Sections
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Duration Breakdown
                  _buildDurationBreakdown(rp, theme),
                  const SizedBox(height: 16),

                  // 2. Live Stopwatch Counter
                  _LiveStopwatchWidget(startDate: rp.startDateTime, theme: theme),
                  const SizedBox(height: 16),

                  // 3. Next Milestone Progress
                  _buildMilestoneProgress(rp, theme),
                  const SizedBox(height: 16),

                  // 4. Anniversary Countdown
                  _buildAnniversaryCountdown(startDate, rp.years, theme),
                  const SizedBox(height: 16),

                  // 5. Fun Statistics Grid
                  _buildFunStatistics(startDate, rp, theme),
                  const SizedBox(height: 24),

                  // 6. Milestone Achieved Timeline
                  _buildMilestonesTimeline(startDate, totalDays, theme),
                  const SizedBox(height: 24),

                  // 7. Memories Highlight Section
                  _buildMemoriesHighlight(tp, theme),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Duration Breakdown Bento Grids
  Widget _buildDurationBreakdown(RelationshipProvider rp, LoveStoryTheme theme) {
    final age = rp.preciseAge;
    final years = age['years'] ?? 0;
    final months = age['months'] ?? 0;
    final days = age['days'] ?? 0;

    Widget buildTile(int targetValue, String label, String icon) {
      return Expanded(
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: targetValue.toDouble()),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Text(
                    '${value.toInt()}',
                    style: AppTypography.sectionHeader(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: theme.textColor,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        buildTile(years, years == 1 ? 'Year' : 'Years', '🎉'),
        const SizedBox(width: 12),
        buildTile(months, months == 1 ? 'Month' : 'Months', '🗓'),
        const SizedBox(width: 12),
        buildTile(days, days == 1 ? 'Day' : 'Days', '💖'),
      ],
    );
  }

  // Next Milestone Progress
  Widget _buildMilestoneProgress(RelationshipProvider rp, LoveStoryTheme theme) {
    final milestones = rp.nextMilestones;
    if (milestones.isEmpty) return const SizedBox.shrink();

    final next = milestones.first;
    // Extract target days from title
    int target = 100;
    final numMatch = RegExp(r'\d+').firstMatch(next.title);
    if (numMatch != null) {
      target = int.tryParse(numMatch.group(0)!) ?? 100;
    }

    final currentDays = rp.totalDays;
    final progress = next.progress;
    final percent = (progress * 100).round();

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEXT MILESTONE',
                    style: AppTypography.cardCategory(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: theme.accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    next.title,
                    style: AppTypography.cardTitle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: percent.toDouble()),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${value.toInt()}%',
                      style: AppTypography.captionMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.accentColor,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: theme.textColor.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$currentDays / $target Days',
                style: AppTypography.caption(
                  fontSize: 11,
                  color: theme.textColor.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${next.daysUntil} days remaining',
                style: AppTypography.caption(
                  fontSize: 11,
                  color: theme.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          // List remaining 4 milestones
          if (milestones.length > 1) ...[
            const Divider(height: 24, thickness: 0.5),
            Text(
              'Upcoming Milestones',
              style: AppTypography.captionMono(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: theme.textColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: List.generate(milestones.length - 1, (index) {
                final milestone = milestones[index + 1];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star_border_rounded, size: 14, color: theme.textColor.withValues(alpha: 0.35)),
                          const SizedBox(width: 8),
                          Text(
                            milestone.title,
                            style: AppTypography.bodyMedium(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: theme.textColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'in ${milestone.daysUntil} days',
                        style: AppTypography.caption(
                          fontSize: 11,
                          color: theme.textColor.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  // Anniversary Countdown Card
  Widget _buildAnniversaryCountdown(DateTime startDate, int currentYears, LoveStoryTheme theme) {
    final nextAnniversaryYear = currentYears + 1;
    final nextAnniversaryDate = DateHelper.getAnniversaryDate(startDate, nextAnniversaryYear);
    final daysUntil = DateHelper.daysUntil(nextAnniversaryDate);

    // Format anniversary title ordinal (e.g. 4th)
    String getOrdinal(int n) {
      if (n >= 11 && n <= 13) return '${n}th';
      switch (n % 10) {
        case 1: return '${n}st';
        case 2: return '${n}nd';
        case 3: return '${n}rd';
        default: return '${n}th';
      }
    }

    final label = '${getOrdinal(nextAnniversaryYear)} Anniversary';

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite_rounded, color: theme.accentColor, size: 24),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT ANNIVERSARY',
                  style: AppTypography.cardCategory(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTypography.cardTitle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMMM dd, yyyy').format(nextAnniversaryDate),
                  style: AppTypography.caption(
                    fontSize: 11,
                    color: theme.textColor.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: daysUntil.toDouble()),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Text(
                    '${value.toInt()}',
                    style: AppTypography.sectionHeader(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: theme.textColor,
                    ),
                  );
                },
              ),
              Text(
                'Days left',
                style: AppTypography.caption(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Fun Statistics Section
  Widget _buildFunStatistics(DateTime startDate, RelationshipProvider rp, LoveStoryTheme theme) {
    final today = DateTime.now();

    // Helper functions
    int countWeekends(DateTime start, DateTime end) {
      int count = 0;
      DateTime current = DateTime(start.year, start.month, start.day);
      final normalizedEnd = DateTime(end.year, end.month, end.day);
      while (current.isBefore(normalizedEnd) || current.isAtSameMomentAs(normalizedEnd)) {
        if (current.weekday == DateTime.saturday || current.weekday == DateTime.sunday) {
          count++;
        }
        current = current.add(const Duration(days: 1));
      }
      return count;
    }

    int countOccurrencesOfDate(DateTime start, DateTime end, int month, int day) {
      int count = 0;
      for (int y = start.year; y <= end.year; y++) {
        final d = DateTime(y, month, day);
        if ((d.isAfter(start) || d.isAtSameMomentAs(start)) &&
            (d.isBefore(end) || d.isAtSameMomentAs(end))) {
          count++;
        }
      }
      return count;
    }

    final totalDays = rp.totalDays;
    final weekends = countWeekends(startDate, today);
    final valentines = countOccurrencesOfDate(startDate, today, 2, 14);
    final christmases = countOccurrencesOfDate(startDate, today, 12, 25);
    final newYears = countOccurrencesOfDate(startDate, today, 1, 1);

    int birthdays = 0;
    if (rp.yourBirthdate != null) {
      birthdays += countOccurrencesOfDate(startDate, today, rp.yourBirthdate!.month, rp.yourBirthdate!.day);
    }
    if (rp.partnerBirthdate != null) {
      birthdays += countOccurrencesOfDate(startDate, today, rp.partnerBirthdate!.month, rp.partnerBirthdate!.day);
    }

    final stats = [
      _FunStatItem('🌅', 'Sunrises Together', '$totalDays'),
      _FunStatItem('🌙', 'Nights Shared', '$totalDays'),
      _FunStatItem('🗓', 'Weekend Days Shared', '$weekends'),
      _FunStatItem('📆', 'Months Shared', '${rp.totalMonths}'),
      if (birthdays > 0) _FunStatItem('🎂', 'Birthdays Celebrated', '$birthdays'),
      _FunStatItem('💘', 'Valentine\'s Days', '$valentines'),
      _FunStatItem('🎄', 'Christmases Spent', '$christmases'),
      _FunStatItem('🎆', 'New Years Together', '$newYears'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: theme.accentColor, size: 16),
            const SizedBox(width: 8),
            Text(
              'Journey Fun Facts',
              style: AppTypography.cardTitle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final item = stats[index];
            final targetValue = int.tryParse(item.value) ?? 0;
            return GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              borderRadius: 16,
              child: Row(
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: targetValue.toDouble()),
                          duration: Duration(milliseconds: 1000 + index * 120),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return Text(
                              NumberFormat('#,###').format(value.toInt()),
                              style: AppTypography.sectionHeader(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: theme.textColor,
                              ),
                            );
                          },
                        ),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: theme.textColor.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
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

  // Milestone Achievements Timeline
  Widget _buildMilestonesTimeline(DateTime startDate, int totalDays, LoveStoryTheme theme) {
    // Milestones list template
    final achievements = <_AchievedMilestone>[
      _AchievedMilestone('First Day ❤️', 0),
      _AchievedMilestone('30 Days Together 🎉', 30),
      _AchievedMilestone('100 Days Together 💫', 100),
      _AchievedMilestone('1 Year Anniversary 🌹', 365, isAnniversary: true, annivYear: 1),
      _AchievedMilestone('500 Days Together ✨', 500),
      _AchievedMilestone('1,000 Days Together 👑', 1000),
      _AchievedMilestone('2 Years Anniversary 💍', 730, isAnniversary: true, annivYear: 2),
      _AchievedMilestone('1,500 Days Together 🌟', 1500),
      _AchievedMilestone('3 Years Anniversary 🏹', 1095, isAnniversary: true, annivYear: 3),
      _AchievedMilestone('2,000 Days Together 🌈', 2000),
      _AchievedMilestone('4 Years Anniversary 🥂', 1461, isAnniversary: true, annivYear: 4),
      _AchievedMilestone('2,500 Days Together 🛸', 2500),
      _AchievedMilestone('5 Years Anniversary 🪐', 1826, isAnniversary: true, annivYear: 5),
      _AchievedMilestone('3,000 Days Together 🛸', 3000),
      _AchievedMilestone('10 Years Anniversary 💎', 3652, isAnniversary: true, annivYear: 10),
    ];

    // Filter to completed ones
    final achievedList = achievements.where((a) {
      if (a.isAnniversary) {
        // Double check anniversary year offset
        final date = DateHelper.getAnniversaryDate(startDate, a.annivYear);
        final days = DateHelper.calendarDaysBetween(startDate, date);
        return totalDays >= days;
      }
      return totalDays >= a.targetDays;
    }).toList();

    // Chronological date calculator
    DateTime getAchievementDate(_AchievedMilestone item) {
      if (item.isAnniversary) {
        return DateHelper.getAnniversaryDate(startDate, item.annivYear);
      }
      return startDate.add(Duration(days: item.targetDays));
    }

    if (achievedList.isEmpty) return const SizedBox.shrink();

    // Sort descending (newest achieved first)
    achievedList.sort((a, b) {
      final dateA = getAchievementDate(a);
      final dateB = getAchievementDate(b);
      return dateB.compareTo(dateA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: theme.accentColor, size: 16),
            const SizedBox(width: 8),
            Text(
              'Milestones Achieved',
              style: AppTypography.cardTitle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: achievedList.length,
          itemBuilder: (context, index) {
            final item = achievedList[index];
            final date = getAchievementDate(item);
            final formattedDate = DateFormat('MMMM dd, yyyy').format(date);
            final isLast = index == achievedList.length - 1;

            return IntrinsicHeight(
              child: Row(
                children: [
                  // Timeline Node
                  Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: theme.accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.accentColor.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.check, color: Colors.white, size: 8),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: theme.textColor.withValues(alpha: 0.15),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Timeline Card
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        borderRadius: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: AppTypography.bodyLarge(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: theme.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDate,
                                    style: AppTypography.caption(
                                      fontSize: 10.5,
                                      color: theme.textColor.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Days badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.textColor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.isAnniversary 
                                    ? '${item.annivYear} Yr' 
                                    : '${item.targetDays}d',
                                style: AppTypography.captionMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textColor.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  // Memories Highlight Section
  Widget _buildMemoriesHighlight(TimelineProvider tp, LoveStoryTheme theme) {
    final memories = tp.timelineItems;
    TimelineItemData? firstMemory;

    if (memories.isNotEmpty) {
      // Find chronologically first memory
      final sorted = List<TimelineItemData>.from(memories)
        ..sort((a, b) => a.date.compareTo(b.date));
      firstMemory = sorted.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bookmark_rounded, color: theme.accentColor, size: 16),
            const SizedBox(width: 8),
            Text(
              'How It All Started',
              style: AppTypography.cardTitle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (firstMemory != null)
          _buildMemoryCard(firstMemory, theme)
        else
          // Placeholder card
          GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: 24,
            width: double.infinity,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.favorite_rounded, color: theme.accentColor, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your story begins here... ❤️',
                  style: AppTypography.bodyLarge(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Capture your first milestone or photo in the Timeline to highlight it here.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMemoryCard(TimelineItemData memory, LoveStoryTheme theme) {
    final formattedDate = DateFormat('MMMM dd, yyyy').format(memory.date);
    final photoUrl = memory.networkImageUrl ?? (memory.photoUrls.isNotEmpty ? memory.photoUrls.first : null);
    final localPath = memory.imagePath;

    Widget? imageWidget;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      imageWidget = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: StorageImage(
          bucket: StorageBuckets.timeline,
          storageRef: photoUrl,
          localPath: localPath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 180,
          errorWidget: (context) => Container(
            color: theme.textColor.withValues(alpha: 0.05),
            height: 180,
            child: Icon(Icons.broken_image_rounded, color: theme.textColor.withValues(alpha: 0.2), size: 36),
          ),
        ),
      );
    } else if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        imageWidget = ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 180,
          ),
        );
      }
    }

    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageWidget != null) imageWidget,
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'FIRST CAPTURED MEMORY',
                        style: AppTypography.cardCategory(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: theme.accentColor,
                        ),
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: AppTypography.caption(
                        fontSize: 11,
                        color: theme.textColor.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  memory.title.isNotEmpty ? memory.title : 'Our First Day Together',
                  style: AppTypography.cardTitle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                if (memory.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    memory.description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(
                      fontSize: 12.5,
                      color: theme.textColor.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// OPTIMIZED LIVE STOPWATCH WIDGET
// ──────────────────────────────────────────────
class _LiveStopwatchWidget extends StatefulWidget {
  final DateTime startDate;
  final LoveStoryTheme theme;

  const _LiveStopwatchWidget({
    required this.startDate,
    required this.theme,
  });

  @override
  State<_LiveStopwatchWidget> createState() => _LiveStopwatchWidgetState();
}

class _LiveStopwatchWidgetState extends State<_LiveStopwatchWidget>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late Duration _difference;
  late AnimationController _introController;
  late Animation<double> _hoursAnimation;

  @override
  void initState() {
    super.initState();
    _difference = DateTime.now().difference(widget.startDate);

    // Animate hours count-up on first load
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _hoursAnimation = Tween<double>(
      begin: 0,
      end: _difference.inHours.toDouble(),
    ).animate(CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutCubic,
    ));
    _introController.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _difference = DateTime.now().difference(widget.startDate);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _introController.dispose();
    super.dispose();
  }

  Widget _buildUnit(String val, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            val,
            style: AppTypography.sectionHeader(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: widget.theme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: widget.theme.textColor.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hours = _difference.inHours;
    final minutes = _difference.inMinutes % 60;
    final seconds = _difference.inSeconds % 60;

    final hourStr = NumberFormat('#,###').format(hours);
    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = seconds.toString().padLeft(2, '0');

    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      borderRadius: 24,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, color: widget.theme.textColor.withValues(alpha: 0.4), size: 14),
              const SizedBox(width: 6),
              Text(
                'LIVE TIME STOPWATCH',
                style: AppTypography.cardCategory(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: widget.theme.textColor.withValues(alpha: 0.4),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _introController,
            builder: (context, _) {
              final displayHours = _introController.isCompleted
                  ? hourStr
                  : NumberFormat('#,###').format(_hoursAnimation.value.toInt());
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildUnit(displayHours, 'Hours'),
                  Text(
                    ':',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: widget.theme.textColor.withValues(alpha: 0.4),
                    ),
                  ),
                  _buildUnit(minStr, 'Minutes'),
                  Text(
                    ':',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: widget.theme.textColor.withValues(alpha: 0.4),
                    ),
                  ),
                  _buildUnit(secStr, 'Seconds'),
                ],
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.white10,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      NumberFormat('#,###').format(_difference.inMinutes),
                      style: AppTypography.sectionHeader(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: widget.theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Minutes Passed',
                      style: AppTypography.caption(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: widget.theme.textColor.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 0.5,
                height: 32,
                color: Colors.white10,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      NumberFormat('#,###').format(_difference.inSeconds),
                      style: AppTypography.sectionHeader(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: widget.theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Seconds Passed',
                      style: AppTypography.caption(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: widget.theme.textColor.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// HELPERS
// ──────────────────────────────────────────────
class _FunStatItem {
  final String emoji;
  final String label;
  final String value;
  _FunStatItem(this.emoji, this.label, this.value);
}

class _AchievedMilestone {
  final String title;
  final int targetDays;
  final bool isAnniversary;
  final int annivYear;

  _AchievedMilestone(
    this.title,
    this.targetDays, {
    this.isAnniversary = false,
    this.annivYear = 0,
  });
}
