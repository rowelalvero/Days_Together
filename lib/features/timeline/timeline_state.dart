import 'package:days_together/models/timeline_model.dart';

/// State for `TimelineController` (Phase 6a of the architecture migration)
/// -- a direct Riverpod port of `TimelineProvider`'s `_timelineItems`/
/// `_isLoading`/`_isAscending`/`_currentScrubIndex` fields. `_localMutations`
/// and `_locallyDeletedIds` stay as private controller fields, not state --
/// they are write-echo bookkeeping the UI never reads, matching how every
/// other Phase 6a controller keeps `_localMutations` off its public state.
class TimelineState {
  final List<TimelineItemData> items;
  final bool isLoading;
  final bool isAscending;
  final int currentScrubIndex;

  const TimelineState({
    this.items = const [],
    this.isLoading = true,
    this.isAscending = true,
    this.currentScrubIndex = 0,
  });

  TimelineState copyWith({
    List<TimelineItemData>? items,
    bool? isLoading,
    bool? isAscending,
    int? currentScrubIndex,
  }) {
    return TimelineState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isAscending: isAscending ?? this.isAscending,
      currentScrubIndex: currentScrubIndex ?? this.currentScrubIndex,
    );
  }

  static int clampIndex(List<TimelineItemData> items, int desired) {
    if (items.isEmpty) return 0;
    return desired.clamp(0, items.length - 1);
  }
}
