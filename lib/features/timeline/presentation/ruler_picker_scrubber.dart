import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class RulerPickerScrubber extends StatefulWidget {
  final List<TimelineItemData> items;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final bool isAscending;
  final bool hasBackground;

  const RulerPickerScrubber({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.isAscending,
    this.hasBackground = true,
  });

  @override
  State<RulerPickerScrubber> createState() => _RulerPickerScrubberState();
}

class _RulerPickerScrubberState extends State<RulerPickerScrubber> {
  late ScrollController _scrollController;
  final double _tickWidth = 32.0;
  bool _isManualScrolling = false;
  int _lastNotifiedChronoIndex = -1;

  List<TimelineItemData> get _chronoItems {
    final list = List<TimelineItemData>.from(widget.items);
    if (!widget.isAscending) {
      return list.reversed.toList();
    }
    return list;
  }

  int get _chronoSelectedIndex {
    if (widget.items.isEmpty) return 0;
    return widget.isAscending
        ? widget.selectedIndex
        : widget.items.length - 1 - widget.selectedIndex;
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lastNotifiedChronoIndex = _chronoSelectedIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToChronoIndex(_chronoSelectedIndex, animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant RulerPickerScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentChronoIndex = _chronoSelectedIndex;
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.isAscending != widget.isAscending) {
      _lastNotifiedChronoIndex = currentChronoIndex;
      if (!_isManualScrolling) {
        _scrollToChronoIndex(currentChronoIndex);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToChronoIndex(int chronoIndex, {bool animate = true}) {
    if (!_scrollController.hasClients || widget.items.isEmpty) return;

    final targetOffset = chronoIndex * _tickWidth;

    if (animate) {
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    }
  }

  void _onScrollNotification(ScrollNotification notification, List<TimelineItemData> chronoItems) {
    if (chronoItems.isEmpty) return;

    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _isManualScrolling = true;
      }
    } else if (notification is ScrollUpdateNotification) {
      if (_isManualScrolling) {
        int targetChronoIndex = (_scrollController.offset / _tickWidth).round();
        targetChronoIndex = targetChronoIndex.clamp(0, chronoItems.length - 1);

        if (targetChronoIndex != _lastNotifiedChronoIndex) {
          final direction = targetChronoIndex > _lastNotifiedChronoIndex ? 1 : -1;
          final start = _lastNotifiedChronoIndex;
          final end = targetChronoIndex;

          for (int i = start + direction; i != end + direction; i += direction) {
            final mainIndex = widget.isAscending
                ? i
                : widget.items.length - 1 - i;
            widget.onIndexChanged(mainIndex);
          }
          HapticFeedback.selectionClick();
          _lastNotifiedChronoIndex = targetChronoIndex;
        }
      }
    } else if (notification is ScrollEndNotification) {
      if (_isManualScrolling) {
        _isManualScrolling = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isManualScrolling) {
            _scrollToChronoIndex(_lastNotifiedChronoIndex);
          }
        });
      }
    }
  }

  bool _isYearStart(int index, List<TimelineItemData> chronoItems) {
    if (index == 0) return true;
    return chronoItems[index].date.year != chronoItems[index - 1].date.year;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    final chronoItems = _chronoItems;
    if (chronoItems.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final paddingWidth = screenWidth / 2 - _tickWidth / 2;
    final chronoSelectedIndex = _chronoSelectedIndex;

    final scrubberContent = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScrollNotification(notification, chronoItems);
        return true;
      },
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: paddingWidth),
        itemCount: chronoItems.length,
        itemBuilder: (context, index) {
          final item = chronoItems[index];
          final isSelected = index == chronoSelectedIndex;
          final isYear = _isYearStart(index, chronoItems);

          return GestureDetector(
            onTap: () {
              _isManualScrolling = false;
              final mainIndex = widget.isAscending
                  ? index
                  : widget.items.length - 1 - index;
              widget.onIndexChanged(mainIndex);
              HapticFeedback.selectionClick();
              _scrollToChronoIndex(index);
            },
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: _tickWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The Tick Mark
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 3.0 : 1.5,
                    height: isYear ? 28.0 : 12.0,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.accentColor
                          : (isYear ? Colors.white70 : Colors.white30),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: theme.accentColor.withValues(alpha: 0.6),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Year text or small spacing
                  SizedBox(
                    height: 14,
                    child: isYear
                        ? Text(
                            '${item.date.year}',
                            style: AppTypography.caption(
                              fontSize: 9,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? theme.accentColor : Colors.white70,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (widget.hasBackground) {
      return GlassContainer(
        height: 70,
        width: double.infinity,
        borderRadius: 24,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        opacity: 0.1,
        blur: 20,
        child: scrubberContent,
      );
    } else {
      return SizedBox(
        height: 70,
        width: double.infinity,
        child: scrubberContent,
      );
    }
  }
}
