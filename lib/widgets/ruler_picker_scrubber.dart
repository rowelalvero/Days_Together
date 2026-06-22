import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class RulerPickerScrubber extends StatefulWidget {
  final List<TimelineItemData> items;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;

  const RulerPickerScrubber({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  State<RulerPickerScrubber> createState() => _RulerPickerScrubberState();
}

class _RulerPickerScrubberState extends State<RulerPickerScrubber> {
  late ScrollController _scrollController;
  final double _tickWidth = 32.0;
  bool _isManualScrolling = false;
  int _lastNotifiedIndex = -1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lastNotifiedIndex = widget.selectedIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(widget.selectedIndex, animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant RulerPickerScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _lastNotifiedIndex = widget.selectedIndex;
      if (!_isManualScrolling) {
        _scrollToIndex(widget.selectedIndex);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index, {bool animate = true}) {
    if (!_scrollController.hasClients || widget.items.isEmpty) return;

    final targetOffset = index * _tickWidth;

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

  void _onScrollNotification(ScrollNotification notification) {
    if (widget.items.isEmpty) return;

    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _isManualScrolling = true;
      }
    } else if (notification is ScrollUpdateNotification) {
      if (_isManualScrolling) {
        int targetIndex = (_scrollController.offset / _tickWidth).round();
        targetIndex = targetIndex.clamp(0, widget.items.length - 1);

        if (targetIndex != _lastNotifiedIndex) {
          final direction = targetIndex > _lastNotifiedIndex ? 1 : -1;
          final start = _lastNotifiedIndex;
          final end = targetIndex;

          for (int i = start + direction; i != end + direction; i += direction) {
            widget.onIndexChanged(i);
            HapticFeedback.selectionClick();
          }
          _lastNotifiedIndex = targetIndex;
        }
      }
    } else if (notification is ScrollEndNotification) {
      if (_isManualScrolling) {
        _isManualScrolling = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isManualScrolling) {
            _scrollToIndex(_lastNotifiedIndex);
          }
        });
      }
    }
  }

  bool _isYearStart(int index) {
    if (index == 0) return true;
    return widget.items[index].date.year != widget.items[index - 1].date.year;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    if (widget.items.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final paddingWidth = screenWidth / 2 - _tickWidth / 2;

    return Container(
      height: 70,
      width: double.infinity,
      color: Colors.transparent,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _onScrollNotification(notification);
          return true;
        },
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: paddingWidth),
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final isSelected = index == widget.selectedIndex;
            final isYear = _isYearStart(index);

            return GestureDetector(
              onTap: () {
                _isManualScrolling = false;
                widget.onIndexChanged(index);
                HapticFeedback.selectionClick();
                _scrollToIndex(index);
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
                              style: GoogleFonts.inter(
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
      ),
    );
  }
}
