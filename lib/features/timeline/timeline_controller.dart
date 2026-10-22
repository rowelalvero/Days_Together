import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/models/paging_status.dart';
import 'package:days_together/core/network/row_change.dart';
import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/timeline/timeline_state.dart';
import 'package:days_together/shared/models/timeline_model.dart';
import 'package:days_together/core/storage/encrypted_storage_service.dart';
import 'package:days_together/core/storage/local_persistence_service.dart';
import 'package:days_together/core/notifications/notification_service.dart';
import 'package:days_together/core/permissions/permission_service.dart';
import 'package:days_together/core/activity/recent_activity_service.dart';
import 'package:days_together/core/storage/storage_url_service.dart';
import 'package:days_together/shared/widgets/storage_image.dart'
    show evictStorageImageCache;
import 'package:days_together/core/constants/tables.dart';

/// Riverpod port of `TimelineProvider` (Phase 6a of the architecture
/// migration -- the widest UI consumer surface of the 12, 18 files).
/// Faithful behavior port, including its one deliberate asymmetry:
/// [addTimelineItem]/[updateTimelineItem] do not apply locally on the
/// Supabase success path (rely on the realtime echo, like
/// `GiftReminderController`/`CalendarController`/`TimeCapsuleController`),
/// but [deleteTimelineItem] always applies immediately and optimistically,
/// paired or not, guarding against the realtime stream resurrecting a
/// just-deleted item via `_locallyDeletedIds` -- exactly as the original
/// does, for the same reason (instant delete feedback matters more than a
/// round-trip).
///
/// Paged: when paired, memories load [pageSize] at a time in display order
/// ([loadMore], triggered from [setCurrentScrubIndex] near the end of the
/// window), and live updates arrive as individual row changes, so the whole
/// table is never downloaded. Whole-timeline figures come from
/// [fetchServerStats] (see [TimelineState.memoryCount]). Screens that need
/// memories by date or id rather than by position -- the calendar, Wrapped,
/// a tapped notification -- load them with [ensureRangeLoaded] and
/// [loadMemory] into [TimelineState.detached], never into the window.
class TimelineController extends Notifier<TimelineState>
    with SupabaseLifecycleNotifier<TimelineState> {
  static const int pageSize = 10;

  /// Start fetching the next page this many items before the end.
  static const int prefetchThreshold = 3;

  /// Upper bound for a re-sync that keeps an already scrolled-through window.
  static const int _maxResyncWindow = 200;

  final LocalPersistenceService _repository = LocalPersistenceService();
  final ImagePicker _picker = ImagePicker();
  final Set<String> _locallyDeletedIds = {};
  final Set<String> _localMutations = {};

  /// Keyset position of the last memory paged in from the server, in the
  /// current sort order. Realtime inserts don't move it, so they can never
  /// make a page skip memories.
  TimelineCursor? _cursor;

  /// How many memories have been paged in from the server; a re-sync
  /// (reconnect) reloads that many so the user keeps their place.
  int _pagedCount = 0;
  bool _loadingMore = false;
  Timer? _statsDebounce;

  /// In-flight range and single-memory loads, so overlapping requests for
  /// the same data share one fetch.
  final Map<String, Future<bool>> _rangeLoads = {};
  final Map<String, Future<TimelineItemData?>> _memoryLoads = {};

  /// The saved sort order and the local cache, loaded at build. The server
  /// sync waits for both, so it pages in the right order and the (older)
  /// cache can never land on top of the fresh page.
  Future<void> _localLoad = Future.value();

  @override
  String get tableName => Tables.timelineItems;

  @override
  TimelineState build() {
    ref.onDispose(() => _statsDebounce?.cancel());
    _localLoad = _loadSortOrder().then((_) => _loadFromCache());
    initSessionLifecycle();
    return const TimelineState();
  }

  Future<void> _loadSortOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAscending = prefs.getBool(PrefsKeys.timelineIsAscending) ?? true;
      if (!ref.mounted) return;
      state = state.copyWith(isAscending: isAscending);
    } catch (e) {
      debugPrint('TimelineController._loadSortOrder error: $e');
    }
  }

  List<TimelineItemData> _sorted(List<TimelineItemData> items, bool ascending) {
    // (date, id): the same order the server pages in.
    final sorted = List<TimelineItemData>.from(items)
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        final cmp = byDate != 0 ? byDate : a.id.compareTo(b.id);
        return ascending ? cmp : -cmp;
      });
    for (var i = 0; i < sorted.length; i++) {
      sorted[i] = sorted[i].copyWith(position: i);
    }
    return sorted;
  }

  Future<void> toggleSortOrder() async {
    final oldItem =
        state.items.isNotEmpty && state.currentScrubIndex < state.items.length
        ? state.items[state.currentScrubIndex]
        : null;
    final nextAscending = !state.isAscending;
    if (coupleId != null && state.paging.hasMore) {
      // Only part of the timeline is loaded, so the other end is not here:
      // start again from the first page in the new order.
      state = state.copyWith(isAscending: nextAscending, currentScrubIndex: 0);
      _pagedCount = 0;
      await _saveSortOrder(nextAscending);
      await syncInitialData();
      return;
    }
    final resorted = _sorted(state.items, nextAscending);

    var newIndex = state.currentScrubIndex;
    if (oldItem != null) {
      final found = resorted.indexWhere((item) => item.id == oldItem.id);
      if (found != -1) newIndex = found;
    }

    state = state.copyWith(
      isAscending: nextAscending,
      items: resorted,
      currentScrubIndex: TimelineState.clampIndex(resorted, newIndex),
    );

    await _saveSortOrder(nextAscending);
    await _persistLocalOnly();
  }

  Future<void> _saveSortOrder(bool ascending) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrefsKeys.timelineIsAscending, ascending);
    } catch (e) {
      debugPrint('TimelineController.toggleSortOrder error: $e');
    }
  }

  @override
  Future<void> purgeCache() async {
    _cursor = null;
    _pagedCount = 0;
    _statsDebounce?.cancel();
    _rangeLoads.clear();
    _memoryLoads.clear();
    state = state.copyWith(
      items: [],
      isLoading: false,
      paging: const PagingStatus(),
      detached: const {},
      loadedMonths: const {},
      clearServerStats: true,
    );
    try {
      await _repository.saveTimelineItems([]);
    } catch (e) {
      debugPrint('TimelineController.purgeCache error: $e');
    }
  }

  TimelineItemData _parseItem(Map<String, dynamic> data) {
    final rawComments = data['comments'];
    List<CommentData> parsedComments = [];
    if (rawComments != null) {
      if (rawComments is List) {
        parsedComments = rawComments
            .map((c) => CommentData.fromJson(c as Map<String, dynamic>))
            .toList();
      } else if (rawComments is String) {
        try {
          final decoded = jsonDecode(rawComments);
          if (decoded is List) {
            parsedComments = decoded
                .map((c) => CommentData.fromJson(c as Map<String, dynamic>))
                .toList();
          }
        } catch (e) {
          debugPrint('TimelineController._parseItem comments decode error: $e');
        }
      }
    }
    return TimelineItemData(
      id: data['id'] as String,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] as String?,
      imagePath: data['image_path'] as String?,
      networkImageUrl: data['network_image_url'] as String?,
      date: data['date'] != null
          ? DateTime.parse(data['date'] as String).toLocal()
          : DateTime.now(),
      isImageCard: data['is_image_card'] ?? false,
      position: data['position'] ?? 0,
      mood: data['mood'] ?? '😍',
      photoUrls: List<String>.from(data['photo_urls'] ?? []),
      isPinned: data['is_pinned'] ?? false,
      comments: parsedComments,
    );
  }

  /// One page of memories in display order, strictly after [after] in that
  /// order. Overridden in tests.
  @visibleForTesting
  Future<List<Map<String, dynamic>>> fetchPage({
    required bool ascending,
    TimelineCursor? after,
    required int limit,
  }) => queryPage(
    Supabase.instance.client,
    coupleId: coupleId!,
    ascending: ascending,
    after: after,
    limit: limit,
  );

  /// Whole-timeline figures the page window can't answer. Overridden in
  /// tests.
  @visibleForTesting
  Future<TimelineServerStats> fetchServerStats() =>
      queryServerStats(Supabase.instance.client, coupleId: coupleId!);

  /// The page query: keyset on (date, id), matching [_sorted], served by the
  /// (couple_id, date) index. Static so the e2e test runs this exact query
  /// against a real server.
  static Future<List<Map<String, dynamic>>> queryPage(
    SupabaseClient client, {
    required String coupleId,
    required bool ascending,
    TimelineCursor? after,
    required int limit,
  }) async {
    var query = client
        .from(Tables.timelineItems)
        .select()
        .eq('couple_id', coupleId);
    if (after != null) {
      final op = ascending ? 'gt' : 'lt';
      final date = after.date.toUtc().toIso8601String();
      query = query.or(
        'date.$op."$date",and(date.eq."$date",id.$op.${after.id})',
      );
    }
    return await query
        .order('date', ascending: ascending)
        .order('id', ascending: ascending)
        .limit(limit);
  }

  /// Memories dated in [from, to), oldest first, after [after]; used to
  /// load whole months/years for the calendar and Wrapped.
  static Future<List<Map<String, dynamic>>> queryRange(
    SupabaseClient client, {
    required String coupleId,
    required DateTime from,
    required DateTime to,
    TimelineCursor? after,
    required int limit,
  }) async {
    var query = client
        .from(Tables.timelineItems)
        .select()
        .eq('couple_id', coupleId)
        .gte('date', from.toUtc().toIso8601String())
        .lt('date', to.toUtc().toIso8601String());
    if (after != null) {
      final date = after.date.toUtc().toIso8601String();
      query = query.or(
        'date.gt."$date",and(date.eq."$date",id.gt.${after.id})',
      );
    }
    return await query
        .order('date', ascending: true)
        .order('id', ascending: true)
        .limit(limit);
  }

  /// One memory by id, or null if it doesn't exist (or isn't this
  /// couple's: RLS hides it).
  static Future<Map<String, dynamic>?> queryById(
    SupabaseClient client, {
    required String coupleId,
    required String id,
  }) {
    return client
        .from(Tables.timelineItems)
        .select()
        .eq('couple_id', coupleId)
        .eq('id', id)
        .maybeSingle();
  }

  /// Overridden in tests.
  @visibleForTesting
  Future<List<Map<String, dynamic>>> fetchRange({
    required DateTime from,
    required DateTime to,
    TimelineCursor? after,
    required int limit,
  }) => queryRange(
    Supabase.instance.client,
    coupleId: coupleId!,
    from: from,
    to: to,
    after: after,
    limit: limit,
  );

  /// Overridden in tests.
  @visibleForTesting
  Future<Map<String, dynamic>?> fetchById(String id) =>
      queryById(Supabase.instance.client, coupleId: coupleId!, id: id);

  /// How many memories and photo memories the couple has, and the earliest
  /// one. A photo memory is one with a non-empty image_path or
  /// network_image_url, as in [TimelineState.hasPhoto].
  static Future<TimelineServerStats> queryServerStats(
    SupabaseClient client, {
    required String coupleId,
  }) async {
    final (total, photos, earliest) = await (
      client
          .from(Tables.timelineItems)
          .select('id')
          .eq('couple_id', coupleId)
          .limit(1)
          .count(CountOption.exact),
      client
          .from(Tables.timelineItems)
          .select('id')
          .eq('couple_id', coupleId)
          .or('image_path.neq."",network_image_url.neq.""')
          .limit(1)
          .count(CountOption.exact),
      client
          .from(Tables.timelineItems)
          .select()
          .eq('couple_id', coupleId)
          .order('date', ascending: true)
          .order('id', ascending: true)
          .limit(1),
    ).wait;
    return (
      total: total.count,
      photos: photos.count,
      earliest: earliest.isEmpty ? null : earliest.first,
    );
  }

  static TimelineCursor? _cursorAfter(List<TimelineItemData> page) =>
      page.isEmpty ? null : (date: page.last.date, id: page.last.id);

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    // Dropped if the user/couple changes while this is in flight
    // (audit F-15) -- see SupabaseLifecycleNotifier.isStale.
    final generation = sessionGeneration;
    // Also keeps every state read below out of build(), which can call this
    // synchronously before the first state exists.
    await _localLoad;
    if (isStale(generation) || !ref.mounted) return;
    final ascending = state.isAscending;
    // A re-sync (reconnect) reloads the window the user has already scrolled
    // through, so they keep their place.
    final limit = _pagedCount.clamp(pageSize, _maxResyncWindow);
    try {
      final res = await fetchPage(ascending: ascending, limit: limit);
      if (isStale(generation) || state.isAscending != ascending) return;
      final page = res.map(_parseItem).toList();
      _cursor = _cursorAfter(page);
      _pagedCount = page.length;
      final parsed = _sorted(
        page.where((i) => !_locallyDeletedIds.contains(i.id)).toList(),
        ascending,
      );

      state = state.copyWith(
        items: parsed,
        isLoading: false,
        paging: PagingStatus(hasMore: page.length == limit),
        currentScrubIndex: TimelineState.clampIndex(
          parsed,
          state.currentScrubIndex,
        ),
      );
      await _repository.saveTimelineItems(state.items);
    } catch (e) {
      debugPrint('TimelineController.syncInitialData error: $e');
      if (isStale(generation) || !ref.mounted) return;
      // The cached window (if any) stays on screen; the footer offers a
      // retry, which re-runs this since no page has been loaded yet.
      _cursor = null;
      state = state.copyWith(
        isLoading: false,
        paging: const PagingStatus(hasMore: true, loadMoreFailed: true),
      );
      return;
    }
    await _refreshServerStats();
  }

  /// Appends the next page. Safe to call repeatedly: one fetch at a time,
  /// and a no-op once the server has nothing more.
  Future<void> loadMore() async {
    final cursor = _cursor;
    if (coupleId == null ||
        !state.paging.hasMore ||
        _loadingMore ||
        cursor == null) {
      return;
    }
    _loadingMore = true;
    final generation = sessionGeneration;
    final ascending = state.isAscending;
    state = state.copyWith(
      paging: state.paging.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    try {
      final res = await fetchPage(
        ascending: ascending,
        after: cursor,
        limit: pageSize,
      );
      if (isStale(generation) || state.isAscending != ascending) return;
      final page = res.map(_parseItem).toList();
      _cursor = _cursorAfter(page) ?? cursor;
      _pagedCount += page.length;
      final byId = {for (final item in state.items) item.id: item};
      for (final item in page) {
        if (!_locallyDeletedIds.contains(item.id)) byId[item.id] = item;
      }
      final merged = _sorted(byId.values.toList(), ascending);
      state = state.copyWith(
        items: merged,
        paging: PagingStatus(hasMore: page.length == pageSize),
        currentScrubIndex: TimelineState.clampIndex(
          merged,
          state.currentScrubIndex,
        ),
      );
      await _persistLocalOnly();
    } catch (e) {
      debugPrint('TimelineController.loadMore error: $e');
      if (ref.mounted && !isStale(generation)) {
        state = state.copyWith(
          paging: state.paging.copyWith(loadMoreFailed: true),
        );
      }
    } finally {
      _loadingMore = false;
      if (ref.mounted && state.paging.isLoadingMore) {
        state = state.copyWith(
          paging: state.paging.copyWith(isLoadingMore: false),
        );
      }
    }
  }

  /// The footer's "Try again": reloads the first page if that is what
  /// failed, otherwise the next one.
  Future<void> retryLoad() async {
    if (_cursor == null) {
      _pagedCount = 0;
      state = state.copyWith(
        paging: state.paging.copyWith(isLoadingMore: true),
      );
      await syncInitialData();
      if (ref.mounted && state.paging.isLoadingMore) {
        state = state.copyWith(
          paging: state.paging.copyWith(isLoadingMore: false),
        );
      }
      return;
    }
    await loadMore();
  }

  /// Makes sure every memory dated in [from, to) is loaded (in the window or
  /// [TimelineState.detached]), a whole month at a time; already-loaded
  /// months are not fetched again, and overlapping calls share one fetch.
  /// Returns false if the fetch failed. Unpaired, everything is local
  /// already.
  Future<bool> ensureRangeLoaded(DateTime from, DateTime to) async {
    if (coupleId == null) return true;
    final months = <DateTime>[];
    for (
      var m = DateTime(from.year, from.month);
      m.isBefore(to);
      m = DateTime(m.year, m.month + 1)
    ) {
      if (!state.loadedMonths.contains(TimelineState.monthKey(m))) {
        months.add(m);
      }
    }
    if (months.isEmpty) return true;
    final start = months.first;
    final end = DateTime(months.last.year, months.last.month + 1);
    final key = '${start.toIso8601String()}|${end.toIso8601String()}';
    return _rangeLoads[key] ??= _loadRange(start, end, months).whenComplete(() {
      // Block body: remove() returns this very future, and whenComplete
      // waits on whatever its callback returns -- an arrow body deadlocks.
      _rangeLoads.remove(key);
    });
  }

  /// [ensureRangeLoaded] for the month containing [month].
  Future<bool> ensureMonthLoaded(DateTime month) => ensureRangeLoaded(
    DateTime(month.year, month.month),
    DateTime(month.year, month.month + 1),
  );

  Future<bool> _loadRange(
    DateTime from,
    DateTime to,
    List<DateTime> months,
  ) async {
    final generation = sessionGeneration;
    const chunk = 500;
    final found = <TimelineItemData>[];
    try {
      TimelineCursor? after;
      while (true) {
        final rows = await fetchRange(
          from: from,
          to: to,
          after: after,
          limit: chunk,
        );
        if (isStale(generation)) return false;
        final page = rows.map(_parseItem).toList();
        found.addAll(page);
        if (page.length < chunk) break;
        after = _cursorAfter(page);
      }
    } catch (e) {
      debugPrint('TimelineController.ensureRangeLoaded error: $e');
      return false;
    }
    if (!ref.mounted) return false;
    final detached = {...state.detached};
    for (final item in found) {
      if (!_locallyDeletedIds.contains(item.id)) detached[item.id] = item;
    }
    state = state.copyWith(
      detached: detached,
      loadedMonths: {
        ...state.loadedMonths,
        for (final m in months) TimelineState.monthKey(m),
      },
    );
    return true;
  }

  /// A memory by id, fetched if it isn't loaded -- for a tapped notification
  /// or a link to a memory outside the window. Null if it no longer exists;
  /// throws if it couldn't be fetched, so the caller can offer a retry.
  Future<TimelineItemData?> loadMemory(String id) {
    final known = state.itemById(id);
    if (known != null) return Future.value(known);
    if (coupleId == null || _locallyDeletedIds.contains(id)) {
      return Future.value(null);
    }
    return _memoryLoads[id] ??= _fetchMemory(id).whenComplete(() {
      // Block body: remove() returns this very future, and whenComplete
      // waits on whatever its callback returns -- an arrow body deadlocks.
      _memoryLoads.remove(id);
    });
  }

  Future<TimelineItemData?> _fetchMemory(String id) async {
    final generation = sessionGeneration;
    final row = await fetchById(id);
    if (isStale(generation) || !ref.mounted || row == null) return null;
    if (_locallyDeletedIds.contains(id)) return null;
    // Arrived via realtime meanwhile.
    final known = state.itemById(id);
    if (known != null) return known;
    final item = _parseItem(row);
    state = state.copyWith(detached: {...state.detached, id: item});
    return item;
  }

  Future<void> _refreshServerStats() async {
    if (coupleId == null) return;
    final generation = sessionGeneration;
    try {
      final stats = await fetchServerStats();
      if (isStale(generation)) return;
      final earliest = stats.earliest == null
          ? null
          : _parseItem(stats.earliest!);
      state = state
          .copyWith(clearServerStats: true)
          .copyWith(
            totalCount: stats.total,
            photoCount: stats.photos,
            earliestItem: earliest,
          );
    } catch (e) {
      debugPrint('TimelineController._refreshServerStats error: $e');
    }
  }

  void _scheduleStatsRefresh() {
    _statsDebounce?.cancel();
    _statsDebounce = Timer(const Duration(milliseconds: 500), () {
      if (ref.mounted) _refreshServerStats();
    });
  }

  /// Row changes, not the whole table on every launch, reconnect and edit
  /// (the `.stream()` this replaces re-sent every memory each time).
  @override
  bool get usesRowChanges => true;

  @override
  void onRowChange(RowChange change) {
    if (!ref.mounted) return;
    final id = change.id;
    if (id == null) return;
    final oldItems = state.items;
    final index = oldItems.indexWhere((item) => item.id == id);
    final detachedOld = state.detached[id];
    final known = index != -1 ? oldItems[index] : detachedOld;
    final logActivity = !state.isLoading;

    if (change.type == RowChangeType.delete) {
      _scheduleStatsRefresh();
      if (known == null) return;
      if (detachedOld != null) {
        state = state.copyWith(detached: {...state.detached}..remove(id));
      }
      if (index != -1) _setItems([...oldItems]..removeAt(index));
      if (_localMutations.remove(id) || !logActivity) return;
      RecentActivityService.instance.logActivity(
        activityType: 'deleted',
        title: 'Partner deleted a memory 🗑️',
        description: 'Deleted: "${known.title}"',
        icon: '🗑️',
        referenceId: id,
        route: 'timeline',
      );
      return;
    }

    // Guards against an in-flight echo resurrecting a just-deleted memory.
    if (_locallyDeletedIds.contains(id)) return;
    final incoming = _parseItem(change.newRecord);

    if (known == null) {
      final monthLoaded = state.loadedMonths.contains(
        TimelineState.monthKey(incoming.date),
      );
      if (change.type == RowChangeType.insert || !state.paging.hasMore) {
        // New memories show straight away (and with nothing left to page
        // in, an unknown one is new to this device too).
        _setItems([...oldItems, incoming]);
      } else if (monthLoaded) {
        // Moved into a month the calendar has loaded.
        state = state.copyWith(detached: {...state.detached, id: incoming});
        return;
      } else {
        // Outside the window: it arrives with its page.
        return;
      }
      _scheduleStatsRefresh();
      if (_localMutations.remove(id) || !logActivity) return;
      RecentActivityService.instance.logActivity(
        activityType: 'created',
        title: 'Partner added a memory 📸',
        description: 'Added: "${incoming.title}"',
        icon: '📸',
        referenceId: id,
        route: 'timeline',
      );
      return;
    }

    if (detachedOld != null) {
      state = state.copyWith(detached: {...state.detached, id: incoming});
    }
    if (index != -1) _setItems([...oldItems]..[index] = incoming);
    if (TimelineState.hasPhoto(known) != TimelineState.hasPhoto(incoming) ||
        known.date != incoming.date) {
      _scheduleStatsRefresh();
    }
    final changed =
        known.title != incoming.title ||
        known.description != incoming.description ||
        known.date != incoming.date ||
        known.networkImageUrl != incoming.networkImageUrl;
    if (!changed) return;
    if (_localMutations.remove(id) || !logActivity) return;
    RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: 'Partner updated a memory ✏️',
      description: 'Updated: "${incoming.title}"',
      icon: '✏️',
      referenceId: id,
      route: 'timeline',
    );
  }

  void _setItems(List<TimelineItemData> items) {
    final sorted = _sorted(items, state.isAscending);
    state = state.copyWith(
      items: sorted,
      isLoading: false,
      currentScrubIndex: TimelineState.clampIndex(
        sorted,
        state.currentScrubIndex,
      ),
    );
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('TimelineController: Supabase sync error: $error');
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    try {
      final loaded = await _repository.loadTimelineItems();
      if (!ref.mounted) return;
      final sorted = _sorted(loaded, state.isAscending);
      state = state.copyWith(
        items: sorted,
        isLoading: false,
        currentScrubIndex: TimelineState.clampIndex(
          sorted,
          state.currentScrubIndex,
        ),
      );
    } catch (e, st) {
      debugPrint('TimelineController._loadFromCache failed: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(items: [], isLoading: false);
    }
  }

  Future<void> addTimelineItem(TimelineItemData item) async {
    _localMutations.add(item.id);
    if (coupleId != null) {
      try {
        // Stores the storage PATH, not a URL: the bucket is private, so images
        // are rendered through StorageImage, which signs the path on demand.
        String? imageRef;
        if (item.imagePath != null) {
          final file = File(item.imagePath!);
          if (await file.exists()) {
            final storagePath = 'couples/$coupleId/timeline/${item.id}.jpg';
            await EncryptedStorageService.instance.encryptAndUpload(
              bucket: StorageBuckets.timeline,
              storagePath: storagePath,
              plaintext: await file.readAsBytes(),
            );
            imageRef = storagePath;
          }
        }

        final sortedList = List<TimelineItemData>.from(state.items)..add(item);
        sortedList.sort(
          (a, b) => state.isAscending
              ? a.date.compareTo(b.date)
              : b.date.compareTo(a.date),
        );
        final calculatedPosition = sortedList.indexOf(item);

        final Map<String, dynamic> dbData = {
          'id': item.id,
          'couple_id': coupleId,
          'title': item.title,
          'description': item.description,
          'location': item.location,
          'image_path': item.imagePath,
          'network_image_url': imageRef ?? item.networkImageUrl,
          'date': item.date.toUtc().toIso8601String(),
          'is_image_card': item.isImageCard,
          'position': calculatedPosition,
          'mood': item.mood,
          'photo_urls': item.photoUrls,
          'is_pinned': item.isPinned,
          'comments': item.comments.map((c) => c.toJson()).toList(),
        };

        try {
          await Supabase.instance.client
              .from(Tables.timelineItems)
              .upsert(dbData);
        } catch (e) {
          if (_isMissingCommentsColumn(e)) {
            final fallbackData = Map<String, dynamic>.from(dbData)
              ..remove('comments');
            await Supabase.instance.client
                .from(Tables.timelineItems)
                .upsert(fallbackData);
          } else {
            rethrow;
          }
        }

        try {
          await NotificationService().sendPartnerNotification(
            title: 'New Memory Shared 📸',
            body: 'A new memory was added: ${item.title}',
            feature: 'timeline',
            itemId: item.id,
          );
        } catch (fcmError) {
          debugPrint(
            'TimelineController: Failed to trigger push notification: $fcmError',
          );
        }
        // No local apply on success, matching the original: relies on the
        // realtime echo.
      } catch (e) {
        debugPrint('TimelineController.addTimelineItem Supabase error: $e');
        if (!ref.mounted) return;
        final resorted = _sorted([...state.items, item], state.isAscending);
        state = state.copyWith(
          items: resorted,
          currentScrubIndex: TimelineState.clampIndex(
            resorted,
            state.currentScrubIndex,
          ),
        );
        await _persist();
      }
    } else {
      final resorted = _sorted([...state.items, item], state.isAscending);
      state = state.copyWith(
        items: resorted,
        currentScrubIndex: TimelineState.clampIndex(
          resorted,
          state.currentScrubIndex,
        ),
      );
      await _persist();
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Memory added 📸',
      description: 'Added: "${item.title}"',
      icon: '📸',
      referenceId: item.id,
      route: 'timeline',
    );
  }

  bool _isMissingCommentsColumn(Object e) {
    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('comments') &&
        (errorStr.contains('column') ||
            errorStr.contains('pgrst204') ||
            errorStr.contains('does not exist') ||
            errorStr.contains('not found'));
  }

  Future<void> updateTimelineItem(
    String id,
    TimelineItemData updatedItem,
  ) async {
    _localMutations.add(id);
    // The window or a memory loaded on its own (e.g. opened from a
    // notification).
    final existing = state.itemById(id);
    if (existing == null) {
      debugPrint('TimelineController.updateTimelineItem: id $id not found');
      return;
    }

    if (coupleId != null) {
      try {
        String? imageRef = updatedItem.networkImageUrl;
        if (updatedItem.imagePath != null &&
            updatedItem.imagePath != existing.imagePath) {
          final file = File(updatedItem.imagePath!);
          if (await file.exists()) {
            final storagePath =
                'couples/$coupleId/timeline/${updatedItem.id}.jpg';
            await EncryptedStorageService.instance.encryptAndUpload(
              bucket: StorageBuckets.timeline,
              storagePath: storagePath,
              plaintext: await file.readAsBytes(),
            );
            imageRef = storagePath;
            // The object is overwritten in place (same path, upsert), so any
            // signed URL and cached bytes for it are now stale.
            await StorageUrlService.instance.evict(
              bucket: StorageBuckets.timeline,
              ref: storagePath,
            );
            await evictStorageImageCache(
              bucket: StorageBuckets.timeline,
              ref: storagePath,
            );
          }
        }

        final sortedList = List<TimelineItemData>.from(state.items);
        final idx = sortedList.indexWhere((item) => item.id == updatedItem.id);
        if (idx != -1) {
          sortedList[idx] = updatedItem;
        } else {
          sortedList.add(updatedItem);
        }
        sortedList.sort(
          (a, b) => state.isAscending
              ? a.date.compareTo(b.date)
              : b.date.compareTo(a.date),
        );
        final calculatedPosition = sortedList.indexOf(updatedItem);

        final Map<String, dynamic> dbData = {
          'id': updatedItem.id,
          'couple_id': coupleId,
          'title': updatedItem.title,
          'description': updatedItem.description,
          'location': updatedItem.location,
          'image_path': updatedItem.imagePath,
          'network_image_url': imageRef,
          'date': updatedItem.date.toUtc().toIso8601String(),
          'is_image_card': updatedItem.isImageCard,
          'position': calculatedPosition,
          'mood': updatedItem.mood,
          'photo_urls': updatedItem.photoUrls,
          'is_pinned': updatedItem.isPinned,
          'comments': updatedItem.comments.map((c) => c.toJson()).toList(),
        };

        try {
          await Supabase.instance.client
              .from(Tables.timelineItems)
              .upsert(dbData);
        } catch (e) {
          if (_isMissingCommentsColumn(e)) {
            final fallbackData = Map<String, dynamic>.from(dbData)
              ..remove('comments');
            await Supabase.instance.client
                .from(Tables.timelineItems)
                .upsert(fallbackData);
          } else {
            rethrow;
          }
        }
        // No local apply on success, matching the original.
      } catch (e) {
        debugPrint('TimelineController.updateTimelineItem Supabase error: $e');
        if (!ref.mounted) return;
        _applyLocalUpdate(id, updatedItem);
        await _persist();
      }
    } else {
      _applyLocalUpdate(id, updatedItem);
      await _persist();
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: 'Memory updated ✏️',
      description: 'Updated: "${updatedItem.title}"',
      icon: '✏️',
      referenceId: id,
      route: 'timeline',
    );
  }

  void _applyLocalUpdate(String id, TimelineItemData updatedItem) {
    if (state.detached.containsKey(id)) {
      state = state.copyWith(detached: {...state.detached, id: updatedItem});
    }
    final index = state.items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final items = [...state.items];
    items[index] = updatedItem;
    final resorted = _sorted(items, state.isAscending);
    state = state.copyWith(
      items: resorted,
      currentScrubIndex: TimelineState.clampIndex(
        resorted,
        state.currentScrubIndex,
      ),
    );
  }

  Future<void> deleteTimelineItem(String id) async {
    _localMutations.add(id);
    final item = state.itemById(id);
    if (item == null) {
      debugPrint('TimelineController.deleteTimelineItem: id $id not found');
      return;
    }

    // Add to locally deleted set to prevent stream updates from bringing it back.
    _locallyDeletedIds.add(id);

    if (item.imagePath != null) {
      try {
        await _repository.deleteImage(item.imagePath!);
      } catch (e, st) {
        debugPrint('Failed to delete image ${item.imagePath}: $e\n$st');
      }
    }

    // Update local state first for immediate UI response, matching the
    // original -- delete is always optimistic-local, paired or not, unlike
    // add/update.
    if (!ref.mounted) return;
    if (state.detached.containsKey(id)) {
      state = state.copyWith(detached: {...state.detached}..remove(id));
    }
    final remaining = state.items.where((i) => i.id != id).toList();
    for (var i = 0; i < remaining.length; i++) {
      remaining[i] = remaining[i].copyWith(position: i);
    }
    state = state.copyWith(
      items: remaining,
      currentScrubIndex: TimelineState.clampIndex(
        remaining,
        state.currentScrubIndex,
      ),
    );
    await _persist();

    if (coupleId != null) {
      try {
        await Supabase.instance.client
            .from(Tables.timelineItems)
            .delete()
            .eq('id', id);

        try {
          final storagePath = 'couples/$coupleId/timeline/$id.jpg';
          await Supabase.instance.client.storage
              .from(StorageBuckets.timeline)
              .remove([storagePath]);
        } catch (e) {
          debugPrint(
            'TimelineController.deleteTimelineItem storage remove error: $e',
          );
        }

        final currentRemaining = List<TimelineItemData>.from(state.items);
        for (var i = 0; i < currentRemaining.length; i++) {
          await Supabase.instance.client
              .from(Tables.timelineItems)
              .update({'position': i})
              .eq('id', currentRemaining[i].id);
          if (!ref.mounted) return;
        }
      } catch (e) {
        debugPrint('TimelineController.deleteTimelineItem Supabase error: $e');
      }
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'deleted',
      title: 'Memory deleted 🗑️',
      description: 'Deleted: "${item.title}"',
      icon: '🗑️',
      referenceId: id,
      route: 'timeline',
    );
  }

  Future<void> reorderTimelineItems(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= state.items.length) return;
    if (oldIndex < newIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, state.items.length - 1);

    final items = [...state.items];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = state.copyWith(items: items);

    if (coupleId != null) {
      try {
        for (var i = 0; i < state.items.length; i++) {
          await Supabase.instance.client
              .from(Tables.timelineItems)
              .update({'position': i})
              .eq('id', state.items[i].id);
          if (!ref.mounted) return;
        }
        state = state.copyWith(
          currentScrubIndex: TimelineState.clampIndex(
            state.items,
            state.currentScrubIndex,
          ),
        );
      } catch (e) {
        debugPrint(
          'TimelineController.reorderTimelineItems Supabase error: $e',
        );
        if (!ref.mounted) return;
        final reindexed = [
          for (var i = 0; i < state.items.length; i++)
            state.items[i].copyWith(position: i),
        ];
        state = state.copyWith(
          items: reindexed,
          currentScrubIndex: TimelineState.clampIndex(
            reindexed,
            state.currentScrubIndex,
          ),
        );
        await _persist();
      }
    } else {
      final reindexed = [
        for (var i = 0; i < state.items.length; i++)
          state.items[i].copyWith(position: i),
      ];
      state = state.copyWith(
        items: reindexed,
        currentScrubIndex: TimelineState.clampIndex(
          reindexed,
          state.currentScrubIndex,
        ),
      );
      await _persist();
    }
  }

  void setCurrentScrubIndex(int index) {
    state = state.copyWith(
      currentScrubIndex: TimelineState.clampIndex(state.items, index),
    );
    if (state.paging.canAutoLoad &&
        state.currentScrubIndex >= state.items.length - prefetchThreshold) {
      loadMore();
    }
  }

  Future<String?> pickImage(BuildContext context) async {
    final hasPermission = await PermissionService().requestPhotosPermission(
      context,
    );
    if (!hasPermission) return null;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (picked == null) return null;
      final source = File(picked.path);
      if (!await source.exists()) {
        debugPrint('TimelineController.pickImage: source file missing');
        return null;
      }
      return await _repository.saveImageToStorage(source);
    } catch (e, st) {
      debugPrint('TimelineController.pickImage failed: $e\n$st');
      return null;
    }
  }

  Future<void> _persist() async {
    await _persistLocalOnly();
  }

  Future<void> _persistLocalOnly() async {
    try {
      await _repository.saveTimelineItems(state.items);
    } catch (e, st) {
      debugPrint('TimelineController._persistLocalOnly failed: $e\n$st');
    }
  }

  Future<void> addCommentToItem(
    String itemId,
    String content,
    String authorName,
  ) async {
    final existing = state.itemById(itemId);
    if (existing == null) return;

    final updatedComments = List<CommentData>.from(existing.comments)
      ..add(
        CommentData(
          authorName: authorName,
          content: content,
          date: DateTime.now(),
        ),
      );

    final updatedItem = existing.copyWith(comments: updatedComments);
    await updateTimelineItem(itemId, updatedItem);

    if (coupleId != null) {
      try {
        await NotificationService().sendPartnerNotification(
          title: 'New Comment on Memory 💬',
          body: '$authorName commented: "$content"',
          feature: 'timeline',
          itemId: itemId,
        );
      } catch (e) {
        debugPrint(
          'TimelineController: Failed to send comment notification: $e',
        );
      }
    }
  }

  Future<void> deleteCommentFromItem(String itemId, String commentId) async {
    final existing = state.itemById(itemId);
    if (existing == null) return;

    final updatedComments = existing.comments
        .where((c) => c.id != commentId)
        .toList();
    final updatedItem = existing.copyWith(comments: updatedComments);
    await updateTimelineItem(itemId, updatedItem);
  }

  Future<void> togglePinComment(String itemId, String commentId) async {
    final existing = state.itemById(itemId);
    if (existing == null) return;

    final updatedComments = existing.comments.map((c) {
      return c.id == commentId ? c.copyWith(isPinned: !c.isPinned) : c;
    }).toList();
    final updatedItem = existing.copyWith(comments: updatedComments);
    await updateTimelineItem(itemId, updatedItem);
  }
}

/// Keyset position in the timeline's (date, id) order.
typedef TimelineCursor = ({DateTime date, String id});

typedef TimelineServerStats = ({
  int total,
  int photos,
  Map<String, dynamic>? earliest,
});

final timelineControllerProvider =
    NotifierProvider.autoDispose<TimelineController, TimelineState>(
      TimelineController.new,
      dependencies: [coupleSessionProvider],
    );
