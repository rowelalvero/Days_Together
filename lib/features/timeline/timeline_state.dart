import 'package:days_together/core/models/paging_status.dart';
import 'package:days_together/shared/models/timeline_model.dart';

/// State for `TimelineController` (Phase 6a of the architecture migration)
/// -- a direct Riverpod port of `TimelineProvider`'s `_timelineItems`/
/// `_isLoading`/`_isAscending`/`_currentScrubIndex` fields. `_localMutations`
/// and `_locallyDeletedIds` stay as private controller fields, not state --
/// they are write-echo bookkeeping the UI never reads, matching how every
/// other Phase 6a controller keeps `_localMutations` off its public state.
///
/// When paired, [items] is a PAGE WINDOW, not the whole timeline: the
/// controller loads `TimelineController.pageSize` memories at a time, in
/// display order, and [paging] says whether the server has more. Memories
/// loaded for other reasons -- a calendar month, a Wrapped year, a tapped
/// notification -- live in [detached] instead, so they never punch holes in
/// the window. Read memories through [itemById], [memoriesOn] and
/// [knownItems], which cover both; whole-timeline figures come from
/// [memoryCount], [photoMemoryCount] and [firstMemory].
class TimelineState {
  final List<TimelineItemData> items;
  final bool isLoading;
  final bool isAscending;
  final int currentScrubIndex;
  final PagingStatus paging;

  /// Memories loaded outside the page window, by id.
  final Map<String, TimelineItemData> detached;

  /// Months (see [monthKey]) whose memories are all loaded, in [items] or
  /// [detached].
  final Set<String> loadedMonths;

  /// Server-side totals for the whole timeline; null until fetched (and
  /// always null when unpaired, where [items] is everything).
  final int? totalCount;
  final int? photoCount;

  /// The earliest memory on the server, which may be outside the window.
  final TimelineItemData? earliestItem;

  const TimelineState({
    this.items = const [],
    this.isLoading = true,
    this.isAscending = true,
    this.currentScrubIndex = 0,
    this.paging = const PagingStatus(),
    this.detached = const {},
    this.loadedMonths = const {},
    this.totalCount,
    this.photoCount,
    this.earliestItem,
  });

  TimelineState copyWith({
    List<TimelineItemData>? items,
    bool? isLoading,
    bool? isAscending,
    int? currentScrubIndex,
    PagingStatus? paging,
    Map<String, TimelineItemData>? detached,
    Set<String>? loadedMonths,
    int? totalCount,
    int? photoCount,
    TimelineItemData? earliestItem,
    bool clearServerStats = false,
  }) {
    return TimelineState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isAscending: isAscending ?? this.isAscending,
      currentScrubIndex: currentScrubIndex ?? this.currentScrubIndex,
      paging: paging ?? this.paging,
      detached: detached ?? this.detached,
      loadedMonths: loadedMonths ?? this.loadedMonths,
      totalCount: clearServerStats ? null : (totalCount ?? this.totalCount),
      photoCount: clearServerStats ? null : (photoCount ?? this.photoCount),
      earliestItem: clearServerStats
          ? null
          : (earliestItem ?? this.earliestItem),
    );
  }

  bool get hasMore => paging.hasMore;
  bool get isLoadingMore => paging.isLoadingMore;

  /// `yyyy-mm` of [date] in local time -- the calendar's notion of a month.
  static String monthKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}';
  }

  static bool hasPhoto(TimelineItemData i) =>
      (i.imagePath != null && i.imagePath!.isNotEmpty) ||
      (i.networkImageUrl != null && i.networkImageUrl!.isNotEmpty);

  /// A memory by id, from the window or loaded separately.
  TimelineItemData? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return detached[id];
  }

  /// Every memory loaded so far, window first, without duplicates.
  List<TimelineItemData> get knownItems {
    if (detached.isEmpty) return items;
    final windowIds = {for (final i in items) i.id};
    return [
      ...items,
      ...detached.values.where((i) => !windowIds.contains(i.id)),
    ];
  }

  /// Memories dated on [day] (local calendar day). Complete once that
  /// month is in [loadedMonths].
  List<TimelineItemData> memoriesOn(DateTime day) {
    final local = day.toLocal();
    return knownItems.where((i) {
      final d = i.date.toLocal();
      return d.year == local.year &&
          d.month == local.month &&
          d.day == local.day;
    }).toList();
  }

  /// Every memory in the timeline, not just the loaded window.
  int get memoryCount => totalCount ?? items.length;

  /// Every photo memory in the timeline, not just the loaded window.
  int get photoMemoryCount => photoCount ?? items.where(hasPhoto).length;

  /// The earliest-dated memory, or null when there are none.
  ///
  /// Lives here rather than in `FirstMemoryHighlightCard.build()`, which used
  /// to copy the entire list and sort it -- an allocation plus O(N log N) on
  /// every single rebuild -- only to read element 0. One linear scan needs
  /// neither.
  TimelineItemData? get firstMemory {
    TimelineItemData? earliest = earliestItem;
    for (final item in items) {
      if (earliest == null || item.date.isBefore(earliest.date)) {
        earliest = item;
      }
    }
    return earliest;
  }

  static int clampIndex(List<TimelineItemData> items, int desired) {
    if (items.isEmpty) return 0;
    return desired.clamp(0, items.length - 1);
  }
}
