import 'package:days_together/app/theme/theme_manager.dart';
import 'dart:ui';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/session_state.dart';
import 'package:days_together/app/shell/tabs/settings_tab.dart';
import 'package:days_together/app/shell/tabs/studio_tab.dart';
import 'package:days_together/app/shell/tabs/together_tab.dart';
import 'package:days_together/features/timeline/presentation/add_item_dialog.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/features/dashboard/presentation/pages/home_dashboard.dart';
import 'package:days_together/features/timeline/presentation/pages/timeline_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer, Provider;
import 'package:days_together/app/theme/app_typography.dart';

// The application shell: the four-tab scaffold that hosts every feature's
// entry point. HomeDashboard and TimelineTab used to live in this file; they
// were moved to the features that own them (see dashboard/ and timeline/),
// leaving this file responsible only for the scaffold, its tab switching,
// and its own chrome.

class LoveStoryScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const LoveStoryScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<LoveStoryScreen> createState() => LoveStoryScreenState();

  static LoveStoryScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<LoveStoryScreenState>();
  }
}

class LoveStoryScreenState extends ConsumerState<LoveStoryScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;
  ProviderSubscription<SessionState>? _sessionSubscription;

  // Hoisted so each tab's widget identity is stable across LoveStoryScreen
  // rebuilds; combined with IndexedStack below, this keeps every tab's
  // State (scroll position, storybook mode, etc.) alive when switching
  // away and back instead of disposing and recreating it.
  final GlobalKey<TimelineTabState> _timelineTabKey =
      GlobalKey<TimelineTabState>();
  late final List<Widget> _pages = [
    const HomeDashboard(key: PageStorageKey('loveStoryPage_home')),
    TimelineTab(key: _timelineTabKey),
    const TogetherTab(key: PageStorageKey('loveStoryPage_together')),
    const StudioTab(key: PageStorageKey('loveStoryPage_studio')),
    const SettingsTab(key: PageStorageKey('loveStoryPage_settings')),
  ];

  void setIndex(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sessionSubscription = ref.listenManual(sessionControllerProvider, (
        previous,
        next,
      ) {
        _checkPartnerDeletedNotice(next);
      });
      _checkPartnerDeletedNotice(ref.read(sessionControllerProvider));
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.close();
    super.dispose();
  }

  void _checkPartnerDeletedNotice(SessionState state) {
    if (!mounted) return;
    if (state.showPartnerDeletedNotice) {
      ref.read(sessionControllerProvider.notifier).clearPartnerDeletedNotice();
      _showPartnerDeletedDialog();
    }
  }

  void _showPartnerDeletedDialog() {
    final theme = ref.read(themeControllerProvider).currentLoveTheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              'Connection Update',
              style: AppTypography.heading(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              'Your partner has disconnected or deleted their account. To protect your privacy, your profile has returned to a single state. You can link with a new connection code at any time.',
              style: AppTypography.body(
                fontSize: 15,
                color: theme.textColor.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Continue',
                    style: AppTypography.body(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleBackInvoked(bool didPop, dynamic result) {
    if (didPop) return;

    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      HapticFeedback.vibrate();

      final themeProvider = ref.read(themeControllerProvider);
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
              opacity: 0.1,
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
                    style: AppTypography.body(
                      color: theme.textColor,
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

  double get _floatingBarMarginBottom =>
      16.0 + MediaQuery.of(context).padding.bottom;

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final hasTimelineItems = ref.watch(
      timelineControllerProvider.select((s) => s.items.isNotEmpty),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) =>
          _handleBackInvoked(didPop, result),
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
                  painter: DashboardGridPainter(
                    gridColor: theme.textColor.withValues(alpha: 0.015),
                  ),
                ),
              ),
              // Screen Pages Content -- IndexedStack keeps every tab's
              // widget subtree mounted (just visually hidden) so
              // switching tabs no longer disposes and recreates their
              // State (scroll position, in-progress edits, etc.).
              Positioned.fill(
                child: IndexedStack(index: _currentIndex, children: _pages),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildUnifiedFloatingBar(theme),
              ),
            ],
          ),
        ),
        floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
            ? FloatingActionButton(
                onPressed: () {
                  // AddItemDialog is pushed via Navigator, not
                  // context.push, deliberately: despite using
                  // Navigator.push rather than showDialog, it's
                  // conceptually a dialog (full-screen overlay, no deep
                  // link or back-button target of its own) -- out of
                  // ADR-007's scope the same way showDialog sites are.
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
          _currentIndex == 1 && hasTimelineItems
              ? 148.0 + _floatingBarMarginBottom + 16.0
              : 70.0 + _floatingBarMarginBottom + 16.0,
        ),
      ),
    );
  }

  Widget _buildUnifiedFloatingBar(LoveStoryTheme theme) {
    final double marginBot = _floatingBarMarginBottom;

    final isLight = Theme.of(context).brightness == Brightness.light;
    final overlayColor = isLight ? Colors.black : Colors.white;
    final borderColor = isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.2);
    final double opacity = 0.15;

    final timelineState = ref.watch(timelineControllerProvider);
    // The scrubber row's content and interaction logic are defined and
    // owned by TimelineTab (the only tab that uses it); this shared
    // shell just asks it for a widget to slot into its own capsule, so
    // it doesn't need to know about RulerPickerScrubber at all.
    final scrubberRow = _timelineTabKey.currentState?.buildFloatingScrubber(
      timelineState,
      ref.read(timelineControllerProvider.notifier),
    );
    final showScrubber = _currentIndex == 1 && scrubberRow != null;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, marginBot),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        tween: Tween<double>(begin: 35.0, end: showScrubber ? 24.0 : 35.0),
        builder: (context, radius, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: overlayColor.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: borderColor, width: 1.5),
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
                heightFactor: showScrubber ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                child: AnimatedOpacity(
                  opacity: showScrubber ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  child: scrubberRow ?? const SizedBox(height: 78),
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
    LoveStoryTheme theme,
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
    final double fabX =
        scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.minInsets.right -
        scaffoldGeometry.floatingActionButtonSize.width -
        16.0;
    final double fabY =
        scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        bottomOffset;
    return Offset(fabX, fabY);
  }
}

class DashboardGridPainter extends CustomPainter {
  final Color gridColor;
  DashboardGridPainter({this.gridColor = const Color(0x05000000)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
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
