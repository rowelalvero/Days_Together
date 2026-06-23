import 'dart:async';
import 'dart:ui';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/screens/settings_tab.dart';
import 'package:days_together/screens/studio_tab.dart';
import 'package:days_together/screens/together_tab.dart';
import 'package:days_together/widgets/add_item_dialog.dart';
import 'package:days_together/widgets/timeline_item.dart';
import 'package:days_together/widgets/shake_to_hug.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/widgets/storybook_view.dart';
import 'package:days_together/widgets/ruler_picker_scrubber.dart';
import 'package:days_together/widgets/dashboard/detailed_days_counter.dart';
import 'package:days_together/widgets/dashboard/insights_banner.dart';
import 'package:days_together/widgets/dashboard/partner_presence_card.dart';
import 'package:days_together/widgets/dashboard/milestone_card.dart';
import 'package:days_together/widgets/dashboard/memory_highlight_carousel.dart';
import 'package:days_together/widgets/dashboard/relationship_statistics.dart';
import 'package:days_together/widgets/dashboard/bento_grid.dart';
import 'package:days_together/widgets/dashboard/recent_activity_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:google_fonts/google_fonts.dart';


class LoveStoryScreen extends StatefulWidget {
  const LoveStoryScreen({super.key});

  @override
  State<LoveStoryScreen> createState() => _LoveStoryScreenState();
}

class _LoveStoryScreenState extends State<LoveStoryScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  void _handleBackInvoked(bool didPop, dynamic result) {
    if (didPop) return;

    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      HapticFeedback.vibrate();

      final themeProvider = context.read<ThemeProvider>();
      final theme = themeProvider.currentLoveTheme;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Center(
            child: GlassContainer(
              borderRadius: 20,
              opacity: 0.2,
              blur: 20,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.exit_to_app_rounded,
                    color: theme.accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Press back again to exit',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      SystemNavigator.pop();
    }
  }

  double get _floatingBarMarginBottom => 16.0 + MediaQuery.of(context).padding.bottom;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final timelineProvider = context.watch<TimelineProvider>();
    final items = timelineProvider.timelineItems;

    final List<Widget> pages = [
      const HomeDashboard(),
      const TimelineTab(),
      const TogetherTab(),
      const StudioTab(),
      const SettingsTab(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handleBackInvoked(didPop, result),
      child: ShakeToHugWrapper(
        child: Scaffold(
          extendBody: true,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: themeProvider.currentGradient),
            child: Stack(
              children: [
                // Ambient Glow Blobs
                Positioned(
                  top: -100,
                  left: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.primaryColor.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 100,
                  right: -100,
                  child: Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.accentColor.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
                // Custom Grid Overlay Painter
                Positioned.fill(
                  child: CustomPaint(
                    painter: DashboardGridPainter(),
                  ),
                ),
                // Screen Pages Content
                Positioned.fill(
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
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildUnifiedFloatingBar(theme, timelineProvider),
                ),
              ],
            ),
          ),
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
          floatingActionButtonLocation: AnimatedFabLocation(
            _currentIndex == 1 && items.isNotEmpty
                ? 148.0 + _floatingBarMarginBottom + 16.0
                : 70.0 + _floatingBarMarginBottom + 16.0,
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedFloatingBar(dynamic theme, TimelineProvider timelineProvider) {
    final double marginBot = _floatingBarMarginBottom;
    final items = timelineProvider.timelineItems;

    final isLight = Theme.of(context).brightness == Brightness.light;
    final overlayColor = isLight ? Colors.black : Colors.white;
    final borderColor = isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.2);
    final double opacity = 0.15;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, marginBot),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        tween: Tween<double>(
          begin: 35.0,
          end: _currentIndex == 1 && items.isNotEmpty ? 24.0 : 35.0,
        ),
        builder: (context, radius, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: overlayColor.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: borderColor,
                    width: 1.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      overlayColor.withValues(alpha: opacity * 2),
                      overlayColor.withValues(alpha: opacity),
                    ],
                  ),
                ),
                child: child,
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRect(
              child: AnimatedAlign(
                alignment: Alignment.topCenter,
                heightFactor: _currentIndex == 1 && items.isNotEmpty ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                child: AnimatedOpacity(
                  opacity: _currentIndex == 1 && items.isNotEmpty ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  child: SizedBox(
                    height: 78,
                    child: Column(
                      children: [
                        Expanded(
                          child: RulerPickerScrubber(
                            items: items,
                            selectedIndex: timelineProvider.currentScrubIndex,
                            isAscending: timelineProvider.isAscending,
                            hasBackground: false,
                            onIndexChanged: (index) {
                              timelineProvider.setCurrentScrubIndex(index);
                            },
                          ),
                        ),
                        const Divider(
                          color: Colors.white10,
                          height: 1,
                          thickness: 1,
                          indent: 20,
                          endIndent: 20,
                        ),
                        const SizedBox(height: 7),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 70,
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

class AnimatedFabLocation extends FloatingActionButtonLocation {
  final double bottomOffset;
  const AnimatedFabLocation(this.bottomOffset);

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.minInsets.right -
        scaffoldGeometry.floatingActionButtonSize.width -
        16.0;
    final double fabY = scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        bottomOffset;
    return Offset(fabX, fabY);
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
  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RelationshipProvider>();
    final tp = context.watch<TimelineProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailedDaysCounter(relationshipProvider: rp, theme: theme),
            const SizedBox(height: 16),
            InsightsBanner(
              timelineProvider: tp,
              bucketProvider: context.watch<BucketListProvider>(),
              relationshipProvider: rp,
              theme: theme,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: PartnerPresenceCard(relationshipProvider: rp, theme: theme)),
                const SizedBox(width: 12),
                Expanded(child: MilestoneCard(relationshipProvider: rp, theme: theme)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.bookmark_rounded, color: Colors.pinkAccent, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Latest Captured Memories',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MemoryHighlightCarousel(timelineProvider: tp, theme: theme),
            const SizedBox(height: 24),
            RelationshipStatistics(
              theme: theme,
            ),
            const SizedBox(height: 24),
            BentoGrid(
              theme: theme,
            ),
            const SizedBox(height: 24),
            RecentActivityFeed(timelineProvider: tp, theme: theme),
            const SizedBox(height: 120), // Bottom navigation padding
          ],
        ),
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
  late PageController _pageController;
  late ScrollController _scrollController;
  bool _isManualListScrolling = false;
  TimelineProvider? _timelineProvider;

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

        final provider = Provider.of<TimelineProvider>(context, listen: false);
        if (targetIndex != provider.currentScrubIndex) {
          HapticFeedback.selectionClick();
          provider.setCurrentScrubIndex(targetIndex);
        }
      }
    } else if (notification is ScrollEndNotification) {
      if (_isManualListScrolling) {
        _isManualListScrolling = false;
        if (_scrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isManualListScrolling) {
              final provider = Provider.of<TimelineProvider>(context, listen: false);
              final targetOffset = provider.currentScrubIndex * 230.0;
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
    final initialIndex = Provider.of<TimelineProvider>(context, listen: false).currentScrubIndex;
    _pageController = PageController(initialPage: initialIndex);
    _scrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<TimelineProvider>(context, listen: false);
    if (_timelineProvider != provider) {
      _timelineProvider?.removeListener(_onProviderIndexChanged);
      _timelineProvider = provider;
      _timelineProvider?.addListener(_onProviderIndexChanged);
    }
  }

  @override
  void dispose() {
    _timelineProvider?.removeListener(_onProviderIndexChanged);
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onProviderIndexChanged() {
    if (!mounted) return;
    final newIndex = _timelineProvider?.currentScrubIndex ?? 0;
    if (_isStorybookMode) {
      if (_pageController.hasClients && _pageController.page?.round() != newIndex) {
        _pageController.animateToPage(
          newIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      if (!_isManualListScrolling && _scrollController.hasClients) {
        final targetOffset = newIndex * 230.0;
        if ((_scrollController.offset - targetOffset).abs() > 1.0) {
          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }
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
    final currentScrubIndex = timelineProvider.currentScrubIndex;

    return Stack(
      children: [
        Positioned.fill(
          child: Stack(
            children: [
              _isStorybookMode
                  ? StorybookView(
                      items: items,
                      pageController: _pageController,
                      onPageChanged: (index) {
                        if (index != currentScrubIndex) {
                          HapticFeedback.selectionClick();
                          timelineProvider.setCurrentScrubIndex(index);
                        }
                      },
                    )
                  : NotificationListener<ScrollNotification>(
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
                            floating: false,
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
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: items.length,
                                    itemBuilder: (context, index) {
                                      final item = items[index];
                                      return TimelineItemWidget(
                                        key: ValueKey(item.id),
                                        item: item,
                                        index: index,
                                        isSelected: index == currentScrubIndex,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 220)),
                        ],
                      ),
                    ),
              if (items.isNotEmpty)
                Positioned(
                  top: 16,
                  right: 16,
                  child: SafeArea(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'timelineSortToggle',
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            timelineProvider.toggleSortOrder();
                          },
                          backgroundColor: theme.accentColor,
                          foregroundColor: Colors.white,
                          tooltip: timelineProvider.isAscending
                              ? 'Sort: Oldest to Newest'
                              : 'Sort: Newest to Oldest',
                          child: Icon(
                            timelineProvider.isAscending
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                          heroTag: 'storybookModeToggle',
                          onPressed: () {
                            setState(() {
                              _isStorybookMode = !_isStorybookMode;
                            });
                            if (_isStorybookMode) {
                              _pageController = PageController(initialPage: currentScrubIndex);
                            } else {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_scrollController.hasClients) {
                                  _scrollController.animateTo(
                                    (currentScrubIndex * 230.0).clamp(0.0, _scrollController.position.maxScrollExtent),
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
                      ],
                    ),
                  ),
                ),
            ],
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

class DashboardGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 1.0;
    const double step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
