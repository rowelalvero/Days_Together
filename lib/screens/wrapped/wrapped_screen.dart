import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'wrapped_data.dart';
import 'pages/wrapped_page_welcome.dart';
import 'pages/wrapped_page_days.dart';
import 'pages/wrapped_page_growth.dart';
import 'pages/wrapped_page_memories.dart';
import 'pages/wrapped_page_notes.dart';
import 'pages/wrapped_page_bucket.dart';
import 'pages/wrapped_page_mood.dart';
import 'pages/wrapped_page_calendar.dart';
import 'pages/wrapped_page_capsule.dart';
import 'pages/wrapped_page_stats.dart';
import 'pages/wrapped_page_milestones.dart';
import 'pages/wrapped_page_featured_memory.dart';
import 'pages/wrapped_page_letter.dart';
import 'pages/wrapped_page_finale.dart';
import 'package:days_together/features/wrapped/presentation/wrapped_progress_bar.dart';
import 'package:days_together/features/wrapped/presentation/wrapped_nav_overlay.dart';
import 'package:days_together/features/wrapped/presentation/wrapped_cinematic_bg.dart';

/// The main Wrapped story experience.
/// Accepts a pre-computed [WrappedData] snapshot.
/// Displays 14 pages in a full-screen PageView with progress bar and nav overlay.
class WrappedScreen extends StatefulWidget {
  final WrappedData data;

  const WrappedScreen({super.key, required this.data});

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  static const int _totalPages = 14;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _goNext() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goPrevious() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _replay() {
    _pageController.jumpToPage(0);
  }

  void _skip() {
    Navigator.of(context).pop();
  }

  List<Widget> _buildPages() => [
        WrappedPageWelcome(data: widget.data),
        WrappedPageDays(data: widget.data),
        WrappedPageGrowth(data: widget.data),
        WrappedPageMemories(data: widget.data),
        WrappedPageNotes(data: widget.data),
        WrappedPageBucket(data: widget.data),
        WrappedPageMood(data: widget.data),
        WrappedPageCalendar(data: widget.data),
        WrappedPageCapsule(data: widget.data),
        WrappedPageStats(data: widget.data),
        WrappedPageMilestones(data: widget.data),
        WrappedPageFeaturedMemory(data: widget.data),
        WrappedPageLetter(data: widget.data),
        WrappedPageFinale(data: widget.data, onReplay: _replay),
      ];

  @override
  Widget build(BuildContext context) {
    final gradient =
        WrappedGradients.all[_currentPage.clamp(0, WrappedGradients.all.length - 1)];

    return Scaffold(
      backgroundColor: Colors.black,
      body: WrappedCinematicBg(
        colors: gradient,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // PageView
            PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: _buildPages(),
            ),
            // Nav overlay (tap zones + skip button)
            WrappedNavOverlay(
              onNext: _goNext,
              onPrevious: _goPrevious,
              onSkip: _skip,
              isLastPage: _currentPage == _totalPages - 1,
            ),
            // Progress bar + close button at top
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  WrappedProgressBar(
                    totalPages: _totalPages,
                    currentPage: _currentPage,
                  ),
                ],
              ),
            ),
            // Close (X) button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: GestureDetector(
                onTap: _skip,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
