import 'dart:async';
import 'dart:io';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/screens/settings_tab.dart';
import 'package:days_together/screens/studio_tab.dart';
import 'package:days_together/screens/together_tab.dart';
import 'package:days_together/widgets/add_item_dialog.dart';
import 'package:days_together/widgets/timeline_item.dart';
import 'package:days_together/widgets/shake_to_hug.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/widgets/storybook_view.dart';
import 'package:days_together/widgets/ruler_picker_scrubber.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' show lerpDouble;

class LoveStoryScreen extends StatefulWidget {
  const LoveStoryScreen({super.key});

  @override
  State<LoveStoryScreen> createState() => _LoveStoryScreenState();
}

class _LoveStoryScreenState extends State<LoveStoryScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    final List<Widget> pages = [
      const HomeDashboard(),
      const TimelineTab(),
      const TogetherTab(),
      const StudioTab(),
      const SettingsTab(),
    ];

    return ShakeToHugWrapper(
      child: Scaffold(
        extendBody: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: themeProvider.currentGradient),
          child: PageTransitionSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
              return FadeThroughTransition(
                animation: primaryAnimation,
                secondaryAnimation: secondaryAnimation,
                fillColor: Colors.transparent,
                child: child,
              );
            },
            child: pages[_currentIndex],
          ),
        ),
        bottomNavigationBar: _buildBottomNavBar(theme),
        floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
            ? FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddItemDialog()),
                  );
                },
                backgroundColor: theme.accentColor,
                elevation: 10,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
      ),
    );
  }

  Widget _buildBottomNavBar(dynamic theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: GlassContainer(
        height: 70,
        borderRadius: 35,
        opacity: 0.15,
        blur: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              0,
              Icons.home_rounded,
              Icons.home_outlined,
              'Home',
              theme,
            ),
            _buildNavItem(
              1,
              Icons.auto_awesome_motion_rounded,
              Icons.auto_awesome_motion_outlined,
              'Story',
              theme,
            ),
            _buildNavItem(
              2,
              Icons.favorite_rounded,
              Icons.favorite_outline_rounded,
              'Us',
              theme,
            ),
            _buildNavItem(
              3,
              Icons.palette_rounded,
              Icons.palette_outlined,
              'Studio',
              theme,
            ),
            _buildNavItem(
              4,
              Icons.person_rounded,
              Icons.person_outline_rounded,
              'More',
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    dynamic theme,
  ) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.accentColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected
                  ? theme.accentColor
                  : theme.textColor.withValues(alpha: 0.4),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// HOME DASHBOARD
// ──────────────────────────────────────────────

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RelationshipProvider>();
    final tp = context.watch<TimelineProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLiquidHeader(rp, theme),
            const SizedBox(height: 36),
            _buildDetailedGlassCounter(rp, theme),
            const SizedBox(height: 32),
            _buildMetricGrid(rp, theme),
            const SizedBox(height: 40),
            _buildSectionTitle('Upcoming Joy', theme),
            const SizedBox(height: 16),
            _buildUpcomingMilestones(rp, theme),
            const SizedBox(height: 40),
            _buildSectionTitle('Latest Chapter', theme),
            const SizedBox(height: 16),
            _buildQuickMemorySnapshot(tp, theme),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildLiquidHeader(RelationshipProvider rp, dynamic theme) {
    final partnerJoined = rp.partnerId != null;

    return Row(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.accentColor.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white12,
                backgroundImage: partnerJoined && rp.partnerAvatarPath != null
                    ? (rp.partnerAvatarPath!.startsWith('http')
                        ? NetworkImage(rp.partnerAvatarPath!) as ImageProvider
                        : (File(rp.partnerAvatarPath!).existsSync()
                            ? FileImage(File(rp.partnerAvatarPath!))
                            : null))
                    : null,
                child: !partnerJoined ||
                        rp.partnerAvatarPath == null ||
                        (!rp.partnerAvatarPath!.startsWith('http') &&
                            !File(rp.partnerAvatarPath!).existsSync())
                    ? const Icon(Icons.person, color: Colors.white70)
                    : null,
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: partnerJoined
                      ? (rp.isPartnerOnline ? Colors.greenAccent : Colors.grey)
                      : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.backgroundColor, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (partnerJoined) ...[
                Text(
                  rp.partnerName ?? 'Partner',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: theme.textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  rp.isPartnerOnline ? 'Active Now' : 'Offline',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: theme.textColor.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Waiting for your partner to join',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: theme.textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _ThreeDotLoader(
                      style: GoogleFonts.inter(
                        color: theme.textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Waiting to connect...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: theme.textColor.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, dynamic theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: theme.textColor.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildDetailedGlassCounter(RelationshipProvider rp, dynamic theme) {
    final age = rp.preciseAge;

    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      opacity: 0.12,
      child: Column(
        children: [
          Text(
            NumberFormat('#,###').format(rp.totalDays),
            style: GoogleFonts.montserrat(
              fontSize: 88,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
              letterSpacing: -5,
            ),
          ),
          Text(
            'DAYS TOGETHER',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              color: theme.accentColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeUnit('${age['years']}', 'YEARS', theme),
              _buildTimeUnitDivider(theme),
              _buildTimeUnit('${age['months']}', 'MONTHS', theme),
              _buildTimeUnitDivider(theme),
              _buildTimeUnit('${age['days']}', 'DAYS', theme),
            ],
          ),
          const SizedBox(height: 32),
          GlassContainer(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            opacity: 0.05,
            child: Text(
              '${age['hours'].toString().padLeft(2, '0')} : ${age['minutes'].toString().padLeft(2, '0')} : ${age['seconds'].toString().padLeft(2, '0')}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 18,
                color: theme.textColor.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label, dynamic theme) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: theme.textColor.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeUnitDivider(dynamic theme) {
    return Container(
      height: 25,
      width: 1,
      color: theme.textColor.withValues(alpha: 0.1),
    );
  }

  Widget _buildMetricGrid(RelationshipProvider rp, dynamic theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                '${rp.totalMonths}',
                'TOTAL MONTHS',
                theme,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard('${rp.years}', 'YEARS TOGETHER', theme),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildMetricCard(
          NumberFormat('#,###').format(rp.totalHours),
          'TOTAL HOURS SHARED',
          theme,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String value,
    String label,
    dynamic theme, {
    bool fullWidth = false,
  }) {
    return GlassContainer(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: theme.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingMilestones(RelationshipProvider rp, dynamic theme) {
    final milestones = rp.nextMilestones;
    if (milestones.isEmpty) return const SizedBox();

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: milestones.length,
        itemBuilder: (context, index) {
          final m = milestones[index];
          return GlassContainer(
            width: 190,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  m.title,
                  style: GoogleFonts.inter(
                    color: theme.textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            value: m.progress,
                            strokeWidth: 2,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.accentColor,
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          child: Center(
                            child: Icon(
                              Icons.favorite,
                              size: 10,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${m.daysUntil} days left',
                      style: GoogleFonts.inter(
                        color: theme.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickMemorySnapshot(TimelineProvider tp, dynamic theme) {
    if (tp.timelineItems.isEmpty) {
      return GlassContainer(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white24,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              'No memories yet.',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }
    final latest = tp.timelineItems.first;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(latest.mood, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  latest.title,
                  style: GoogleFonts.inter(
                    color: theme.textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                ),
                Text(
                  DateFormat('MMMM dd, yyyy').format(latest.date),
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// TIMELINE TAB
// ──────────────────────────────────────────────

class TimelineTab extends StatefulWidget {
  const TimelineTab({super.key});

  @override
  State<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<TimelineTab> {
  bool _isStorybookMode = false;
  int _currentScrubIndex = 0;
  late PageController _pageController;
  late ScrollController _scrollController;
  bool _isManualListScrolling = false;

  void _onTimelineScrollNotification(ScrollNotification notification, int itemsCount) {
    if (itemsCount == 0) return;

    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _isManualListScrolling = true;
      }
    } else if (notification is ScrollUpdateNotification) {
      if (_isManualListScrolling && _scrollController.hasClients) {
        int targetIndex = (_scrollController.offset / 230.0).round();
        targetIndex = targetIndex.clamp(0, itemsCount - 1);

        if (targetIndex != _currentScrubIndex) {
          final direction = targetIndex > _currentScrubIndex ? 1 : -1;
          final start = _currentScrubIndex;
          final end = targetIndex;

          for (int i = start + direction; i != end + direction; i += direction) {
            HapticFeedback.selectionClick();
          }

          setState(() {
            _currentScrubIndex = targetIndex;
          });
        }
      }
    } else if (notification is ScrollEndNotification) {
      if (_isManualListScrolling) {
        _isManualListScrolling = false;
        if (_scrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isManualListScrolling) {
              final targetOffset = _currentScrubIndex * 230.0;
              _scrollController.animateTo(
                targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentScrubIndex);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showEditTitleDialog(
    BuildContext context,
    RelationshipProvider rp,
    dynamic theme,
  ) {
    final controller = TextEditingController(text: rp.storyTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: const Text(
          'Edit Story Title',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Our Love Story',
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: theme.accentColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              rp.setStoryTitle(controller.text.trim());
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: theme.accentColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timelineProvider = context.watch<TimelineProvider>();
    final rp = context.watch<RelationshipProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final items = timelineProvider.timelineItems;

    if (_currentScrubIndex >= items.length && items.isNotEmpty) {
      _currentScrubIndex = items.length - 1;
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              if (_isStorybookMode)
                StorybookView(
                  items: items,
                  pageController: _pageController,
                  onPageChanged: (index) {
                    if (index != _currentScrubIndex) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _currentScrubIndex = index;
                      });
                    }
                  },
                )
              else
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    _onTimelineScrollNotification(notification, items.length);
                    return false; // Let it bubble up
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 140,
                        floating: true,
                        pinned: false,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        flexibleSpace: FlexibleSpaceBar(
                          centerTitle: true,
                          collapseMode: CollapseMode.parallax,
                          title: GestureDetector(
                            onTap: () => _showEditTitleDialog(context, rp, theme),
                            child: Text(
                              rp.storyTitle,
                              style: GoogleFonts.playfairDisplay(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(context, theme),
                        )
                      else
                        SliverToBoxAdapter(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.0),
                                          Colors.white24,
                                          Colors.white24,
                                          Colors.white.withValues(alpha: 0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              ReorderableListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: items.length,
                                onReorder: (oldIndex, newIndex) {
                                  timelineProvider.reorderTimelineItems(oldIndex, newIndex);
                                },
                                proxyDecorator: (child, index, animation) {
                                  return AnimatedBuilder(
                                    animation: animation,
                                    builder: (context, child) {
                                      final double animValue = Curves.easeInOut.transform(
                                        animation.value,
                                      );
                                      final double scale = lerpDouble(1, 1.05, animValue)!;
                                      return Transform.scale(
                                        scale: scale,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: child,
                                  );
                                },
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return TimelineItemWidget(
                                    key: ValueKey(item.id),
                                    item: item,
                                    index: index,
                                    isSelected: index == _currentScrubIndex,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                ),
              if (items.isNotEmpty)
                Positioned(
                  top: 16,
                  right: 16,
                  child: SafeArea(
                    child: FloatingActionButton.small(
                      heroTag: 'storybookModeToggle',
                      onPressed: () {
                        setState(() {
                          _isStorybookMode = !_isStorybookMode;
                        });
                        if (_isStorybookMode) {
                          _pageController = PageController(initialPage: _currentScrubIndex);
                        } else {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.animateTo(
                                (_currentScrubIndex * 230.0).clamp(0.0, _scrollController.position.maxScrollExtent),
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          });
                        }
                      },
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      child: Icon(_isStorybookMode ? Icons.auto_awesome_motion_rounded : Icons.auto_stories_rounded),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 96),
            child: RulerPickerScrubber(
              items: items,
              selectedIndex: _currentScrubIndex,
              onIndexChanged: (index) {
                setState(() {
                  _currentScrubIndex = index;
                });
                if (_isStorybookMode) {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                } else {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      (index * 230.0).clamp(0.0, _scrollController.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  }
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 64,
              color: theme.accentColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Your story begins here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Every date, every laugh, and every small moment is a chapter in your book. Start capturing your memories together.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AddItemDialog()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded),
                const SizedBox(width: 8),
                Text(
                  'Capture first memory',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeDotLoader extends StatefulWidget {
  final TextStyle style;
  const _ThreeDotLoader({required this.style});

  @override
  State<_ThreeDotLoader> createState() => _ThreeDotLoaderState();
}

class _ThreeDotLoaderState extends State<_ThreeDotLoader> {
  int _dotCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    return Text(
      dots,
      style: widget.style,
    );
  }
}
