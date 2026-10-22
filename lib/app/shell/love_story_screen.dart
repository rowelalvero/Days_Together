import 'dart:ui';
import 'package:days_together/app/shell/animated_fab_location.dart';
import 'package:days_together/app/shell/dashboard_grid_painter.dart';
import 'package:days_together/app/shell/widgets/unified_floating_bar.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/session_state.dart';
import 'package:days_together/app/shell/tabs/settings_tab.dart';
import 'package:days_together/app/shell/tabs/studio_tab.dart';
import 'package:days_together/app/shell/tabs/together_tab.dart';
import 'package:days_together/features/timeline/presentation/widgets/add_item_dialog.dart';
import 'package:days_together/shared/widgets/glass_container.dart';
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
            backgroundColor: theme.primaryColor,
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final hasTimelineItems = ref.watch(
      timelineControllerProvider.select((s) => s.items.isNotEmpty),
    );
    final timelineState = ref.watch(timelineControllerProvider);
    // The scrubber row's content and interaction logic are defined and
    // owned by TimelineTab (the only tab that uses it); this shared shell
    // just asks it for a widget to slot into UnifiedFloatingBar's own
    // capsule, so it doesn't need to know about RulerPickerScrubber at all.
    final scrubberRow = _timelineTabKey.currentState?.buildFloatingScrubber(
      timelineState,
      ref.read(timelineControllerProvider.notifier),
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
                child: UnifiedFloatingBar(
                  currentIndex: _currentIndex,
                  onIndexSelected: (i) => setState(() => _currentIndex = i),
                  scrubberRow: scrubberRow,
                  theme: theme,
                ),
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
              ? 148.0 + floatingBarMarginBottom(context) + 16.0
              : 70.0 + floatingBarMarginBottom(context) + 16.0,
        ),
      ),
    );
  }
}
