import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/timeline/timeline_state.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/timeline/presentation/widgets/timeline_empty_state.dart';
import 'package:days_together/features/timeline/presentation/widgets/timeline_item.dart';
import 'package:days_together/features/timeline/presentation/widgets/storybook_view.dart';
import 'package:days_together/features/timeline/presentation/widgets/ruler_picker_scrubber.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Consumer, Provider;
import 'package:days_together/app/theme/app_typography.dart';

/// The Story/Timeline tab's content, extracted from the shell's
/// love_story_screen.dart (it composed four `timeline` widgets from inside a
/// file the `shell` owned, which inverted the feature boundary). The shell
/// now imports this page instead of reaching into timeline's internals.

// ──────────────────────────────────────────────
// TIMELINE TAB
// ──────────────────────────────────────────────

class TimelineTab extends ConsumerStatefulWidget {
  const TimelineTab({super.key});

  @override
  ConsumerState<TimelineTab> createState() => TimelineTabState();
}

/// Public so the shell can reach [buildFloatingScrubber] through a
/// `GlobalKey<TimelineTabState>` -- the scrubber is rendered by the
/// shell's scaffold but owned by this tab. Matches the existing
/// `LoveStoryScreenState` precedent.
class TimelineTabState extends ConsumerState<TimelineTab> {
  bool _isStorybookMode = false;
  late PageController _pageController;
  late ScrollController _scrollController;
  bool _isManualListScrolling = false;
  late final ProviderSubscription<TimelineState> _timelineSubscription;

  void _onTimelineScrollNotification(
    ScrollNotification notification,
    int itemsCount,
  ) {
    if (itemsCount == 0) return;

    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _isManualListScrolling = true;
      }
    } else if (notification is ScrollUpdateNotification) {
      if (_isManualListScrolling && _scrollController.hasClients) {
        int targetIndex = (_scrollController.offset / 230.0).round();
        targetIndex = targetIndex.clamp(0, itemsCount - 1);

        final state = ref.read(timelineControllerProvider);
        if (targetIndex != state.currentScrubIndex) {
          HapticFeedback.selectionClick();
          ref
              .read(timelineControllerProvider.notifier)
              .setCurrentScrubIndex(targetIndex);
        }
      }
    } else if (notification is ScrollEndNotification) {
      if (_isManualListScrolling) {
        _isManualListScrolling = false;
        if (_scrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isManualListScrolling) {
              final state = ref.read(timelineControllerProvider);
              final targetOffset = state.currentScrubIndex * 230.0;
              _scrollController.animateTo(
                targetOffset.clamp(
                  0.0,
                  _scrollController.position.maxScrollExtent,
                ),
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
    final initialIndex = ref.read(timelineControllerProvider).currentScrubIndex;
    _pageController = PageController(initialPage: initialIndex);
    _scrollController = ScrollController();
    _timelineSubscription = ref.listenManual(
      timelineControllerProvider,
      (previous, next) => _onProviderIndexChanged(next),
    );
  }

  @override
  void dispose() {
    _timelineSubscription.close();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onProviderIndexChanged(TimelineState next) {
    if (!mounted) return;
    final newIndex = next.currentScrubIndex;
    if (_isStorybookMode) {
      if (_pageController.hasClients &&
          _pageController.page?.round() != newIndex) {
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
    String currentStoryTitle,
    LoveStoryTheme theme,
  ) {
    final controller = TextEditingController(text: currentStoryTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.primaryColor,
        title: Text(
          'Edit Story Title',
          style: AppTypography.heading(color: theme.textColor),
        ),
        content: TextField(
          controller: controller,
          style: AppTypography.body(color: theme.textColor),
          decoration: InputDecoration(
            hintText: 'e.g. Our Love Story',
            hintStyle: AppTypography.body(
              color: theme.textColor.withValues(alpha: 0.3),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: theme.accentColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.button(
                color: theme.textColor.withValues(alpha: 0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(workspaceControllerProvider.notifier)
                  .setStoryTitle(controller.text.trim());
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style: AppTypography.button(color: theme.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the scrubber row (ruler picker + divider) shown inside the
  /// shared floating shell bar's capsule when this tab is active and has
  /// items. Defined here since this tab is the only feature that uses
  /// RulerPickerScrubber; `LoveStoryScreenState._buildUnifiedFloatingBar`
  /// reaches this via a `GlobalKey` and slots it into its own capsule,
  /// rather than knowing about the scrubber itself.
  Widget? buildFloatingScrubber(
    TimelineState timelineState,
    TimelineController timelineController,
  ) {
    final items = timelineState.items;
    if (items.isEmpty) return null;
    return SizedBox(
      height: 78,
      child: Column(
        children: [
          Expanded(
            child: RulerPickerScrubber(
              items: items,
              selectedIndex: timelineState.currentScrubIndex,
              isAscending: timelineState.isAscending,
              hasBackground: false,
              onIndexChanged: (index) {
                timelineController.setCurrentScrubIndex(index);
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final timelineState = ref.watch(timelineControllerProvider);
    final timelineController = ref.read(timelineControllerProvider.notifier);
    final storyTitle = ref.watch(workspaceControllerProvider).storyTitle;
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final items = timelineState.items;
    final currentScrubIndex = timelineState.currentScrubIndex;

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
                          timelineController.setCurrentScrubIndex(index);
                        }
                      },
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        _onTimelineScrollNotification(
                          notification,
                          items.length,
                        );
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
                                onTap: () => _showEditTitleDialog(
                                  context,
                                  storyTitle,
                                  theme,
                                ),
                                child: Text(
                                  storyTitle,
                                  style: AppTypography.display(
                                    fontWeight: FontWeight.bold,
                                    color: theme.textColor,
                                    fontSize: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (items.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: TimelineEmptyState(theme: theme),
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
                                              theme.textColor.withValues(
                                                alpha: 0.0,
                                              ),
                                              theme.textColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              theme.textColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              theme.textColor.withValues(
                                                alpha: 0.0,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
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
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 220),
                          ),
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
                            timelineController.toggleSortOrder();
                          },
                          backgroundColor: theme.accentColor,
                          foregroundColor: Colors.white,
                          tooltip: timelineState.isAscending
                              ? 'Sort: Oldest to Newest'
                              : 'Sort: Newest to Oldest',
                          child: Icon(
                            timelineState.isAscending
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
                              _pageController = PageController(
                                initialPage: currentScrubIndex,
                              );
                            } else {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_scrollController.hasClients) {
                                  _scrollController.animateTo(
                                    (currentScrubIndex * 230.0).clamp(
                                      0.0,
                                      _scrollController
                                          .position
                                          .maxScrollExtent,
                                    ),
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                              });
                            }
                          },
                          backgroundColor: theme.accentColor,
                          foregroundColor: Colors.white,
                          child: Icon(
                            _isStorybookMode
                                ? Icons.auto_awesome_motion_rounded
                                : Icons.auto_stories_rounded,
                          ),
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
}
