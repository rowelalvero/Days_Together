import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' show Color, Offset;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:days_together/core/models/paging_status.dart';
import 'package:days_together/core/network/row_change.dart';
import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/features/scrapbook/noteit_state.dart';
import 'package:days_together/shared/models/noteit_model.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/scrapbook/data/noteit_sync_manager.dart';
import 'package:days_together/core/activity/recent_activity_service.dart';
import 'package:days_together/core/constants/tables.dart';
import 'package:days_together/core/storage/storage_url_service.dart';
import 'package:days_together/core/storage/scoped_json_cache.dart';

/// Riverpod port of `NoteitProvider` (Phase 6a of the architecture
/// migration, ported together with `LoveChatController` since both share
/// the `love_notes` table and its realtime subscription -- see both
/// controllers' shared doc note on the "collision" below).
///
/// **`NoteitSyncManager` ownership is deliberately NOT transferred to this
/// controller yet.** `NoteitSyncManager` is a singleton holding a single
/// `NoteitProvider? _provider` reference (`noteit_sync_manager.dart:70`),
/// set via `initialize(provider)` -- currently called only from
/// `NoteitProvider.updateSession` (`noteit_provider.dart:51-56`). Since
/// Phase 6a doesn't convert any UI, the old `NoteitProvider` is still what
/// `noteit_screen.dart` reads and writes through, and it's still alive in
/// `main.dart`'s `MultiProvider` tree, reacting to the same `CoupleSession`
/// changes this controller's own bridge reacts to. If this controller also
/// called `NoteitSyncManager.instance.initialize(this)` from its
/// `updateSession`, both it and the old provider would race to claim the
/// singleton's one `_provider` slot on every pairing event -- and since
/// nothing reads this controller's state yet, "winning" that race would
/// only ever cost the *old* provider (the one actually in use) its sync
/// status updates, a real regression to the live UI for zero benefit today.
/// So [sendDrawing]/[sendText]/[sendPhoto]/[sendCanvas] still call
/// `NoteitSyncManager.instance.enqueue(...)` (the actual Supabase
/// upload/upsert still happens correctly regardless of which provider
/// "owns" the manager), but this controller's own `updateItemSyncStatus`
/// won't be reached by the queue's status callbacks until Phase 6b retires
/// `NoteitProvider` and this controller becomes the sole `initialize()`
/// caller. Until then, an item created directly through this controller
/// (nothing does today) would visibly stay "sending" forever in its own
/// state, even though the underlying data synced fine.
///
/// Paged: when paired, notes load [pageSize] at a time, newest first
/// ([loadMore], driven by the history grid's scroll), so the doodles' stroke
/// payloads are no longer all downloaded up front. A note referenced from
/// elsewhere loads on its own via [ensureLoaded]; a Wrapped year via
/// [ensureRangeLoaded].
class NoteitController extends Notifier<NoteitState>
    with SupabaseLifecycleNotifier<NoteitState> {
  static const ScopedJsonCache _cache = ScopedJsonCache('love_notes_items');
  static const int pageSize = 20;
  static const int _maxResyncWindow = 200;

  /// Keyset position (created_at, id) of the oldest note paged in from the
  /// server; live inserts don't move it.
  NoteitCursor? _cursor;
  int _pagedCount = 0;
  bool _loadingMore = false;
  Timer? _countDebounce;
  Future<void> _localLoad = Future.value();
  final Map<String, Future<bool>> _rangeLoads = {};
  final Set<String> _idsInFlight = {};

  @override
  String get tableName => Tables.loveNotes;

  @override
  NoteitState build() {
    // Per ADR-005: chat and scrapbook are exempted from autoDispose's
    // default teardown, since losing and re-establishing the realtime
    // subscription during a brief background/tab-switch would visibly drop
    // incoming messages during the gap.
    ref.keepAlive();
    ref.onDispose(() => _countDebounce?.cancel());
    // The sync waits for the cache, so the (older) cache can never land on
    // top of the fresh page.
    _localLoad = _loadFromCache();
    initSessionLifecycle();
    return NoteitState(coupleId: coupleId);
  }

  @override
  Future<void> updateSession(CoupleSession session) async {
    await super.updateSession(session);
    if (!ref.mounted) return;
    if (state.coupleId != coupleId) {
      state = state.copyWith(coupleId: coupleId);
    }
    if (session.coupleId != null && session.userId != null) {
      NoteitSyncManager.instance.initialize(this);
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final jsonString = await _cache.read();
      List<NoteitItem> notes;
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        notes = jsonList.map((j) => NoteitItem.fromJson(j)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        notes = _tutorialNotes();
        if (!ref.mounted) return;
        state = state.copyWith(notes: notes, isLoading: false);
        await _persistLocalOnly();
        return;
      }
      if (!ref.mounted) return;
      state = state.copyWith(notes: notes, isLoading: false);
    } catch (e, st) {
      debugPrint('NoteitController._loadFromCache failed: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  List<NoteitItem> _tutorialNotes() {
    return [
      NoteitItem(
        type: NoteitType.text,
        content:
            'Hi there! Welcome to Scrapbook! 💌 Draw a doodle, choose a picture, or write a note to send it directly to your partner!',
        sender: 'partner',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        backgroundColor: const Color(0xFF9D4EDD),
        syncStatus: SyncStatus.synced,
      ),
      NoteitItem(
        type: NoteitType.drawing,
        content: _generateHeartStrokes(),
        sender: 'partner',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        backgroundColor: const Color(0xFFFF4D6D),
        syncStatus: SyncStatus.synced,
      ),
    ];
  }

  @override
  Future<void> purgeCache() async {
    _cursor = null;
    _pagedCount = 0;
    _countDebounce?.cancel();
    _rangeLoads.clear();
    _idsInFlight.clear();
    state = state.copyWith(
      notes: [],
      isLoading: false,
      paging: const PagingStatus(),
      detached: const {},
      clearTotalCount: true,
    );
    await _cache.clearAll();
  }

  /// One page of notes (never chat), newest first, strictly older than
  /// [before] in (created_at, id) order. Static so the e2e test runs this
  /// exact query against a real server.
  static Future<List<Map<String, dynamic>>> queryPage(
    SupabaseClient client, {
    required String coupleId,
    NoteitCursor? before,
    required int limit,
  }) async {
    var query = client
        .from(Tables.loveNotes)
        .select()
        .eq('couple_id', coupleId)
        // Chat shares love_notes; filtering it server-side keeps every
        // chat line out of this download (audit F-18).
        .neq('type', 'chat');
    if (before != null) {
      final at = before.createdAt.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt."$at",and(created_at.eq."$at",id.lt.${before.id})',
      );
    }
    return await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
  }

  /// How many notes (not chat) the couple has.
  static Future<int> queryCount(
    SupabaseClient client, {
    required String coupleId,
  }) async {
    final res = await client
        .from(Tables.loveNotes)
        .select('id')
        .eq('couple_id', coupleId)
        .neq('type', 'chat')
        .limit(1)
        .count(CountOption.exact);
    return res.count;
  }

  /// Notes by id (chat rows excluded); missing ids are simply absent.
  static Future<List<Map<String, dynamic>>> queryByIds(
    SupabaseClient client, {
    required String coupleId,
    required List<String> ids,
  }) async {
    return await client
        .from(Tables.loveNotes)
        .select()
        .eq('couple_id', coupleId)
        .neq('type', 'chat')
        .inFilter('id', ids);
  }

  /// Notes created in [from, to), for Wrapped.
  static Future<List<Map<String, dynamic>>> queryRange(
    SupabaseClient client, {
    required String coupleId,
    required DateTime from,
    required DateTime to,
  }) async {
    return await client
        .from(Tables.loveNotes)
        .select()
        .eq('couple_id', coupleId)
        .neq('type', 'chat')
        .gte('created_at', from.toUtc().toIso8601String())
        .lt('created_at', to.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(2000);
  }

  // Overridden in tests.
  @visibleForTesting
  Future<List<Map<String, dynamic>>> fetchPage({
    NoteitCursor? before,
    required int limit,
  }) => queryPage(
    Supabase.instance.client,
    coupleId: coupleId!,
    before: before,
    limit: limit,
  );

  @visibleForTesting
  Future<int> fetchCount() =>
      queryCount(Supabase.instance.client, coupleId: coupleId!);

  @visibleForTesting
  Future<List<Map<String, dynamic>>> fetchByIds(List<String> ids) =>
      queryByIds(Supabase.instance.client, coupleId: coupleId!, ids: ids);

  @visibleForTesting
  Future<List<Map<String, dynamic>>> fetchRange(DateTime from, DateTime to) =>
      queryRange(
        Supabase.instance.client,
        coupleId: coupleId!,
        from: from,
        to: to,
      );

  static NoteitCursor? _cursorAfter(List<NoteitItem> page) =>
      page.isEmpty ? null : (createdAt: page.last.createdAt, id: page.last.id);

  static List<NoteitItem> _newestFirst(Iterable<NoteitItem> notes) =>
      notes.toList()..sort((a, b) {
        final byDate = b.createdAt.compareTo(a.createdAt);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    // Dropped if the user/couple changes while this is in flight
    // (audit F-15) -- see SupabaseLifecycleNotifier.isStale.
    final generation = sessionGeneration;
    await _localLoad;
    if (isStale(generation) || !ref.mounted) return;
    // A re-sync (reconnect) reloads what was already scrolled through.
    final limit = _pagedCount.clamp(pageSize, _maxResyncWindow);
    try {
      final res = await fetchPage(limit: limit);
      if (isStale(generation)) return;
      final parsed = res
          .map((data) => NoteitItem.fromSupabase(data, sessionUserId!))
          .toList();
      _cursor = _cursorAfter(_newestFirst(parsed));
      _pagedCount = parsed.length;

      final localUnsynced = state.notes
          .where((n) => n.syncStatus != SyncStatus.synced && n.sender == 'you')
          .toList();
      final Map<String, NoteitItem> mergedMap = {};
      for (final note in parsed) {
        mergedMap[note.id] = note;
      }
      for (final note in localUnsynced) {
        mergedMap.putIfAbsent(note.id, () => note);
      }

      state = state.copyWith(
        notes: _newestFirst(mergedMap.values),
        isLoading: false,
        paging: PagingStatus(hasMore: parsed.length == limit),
      );
      await _persistLocalOnly();
    } catch (e) {
      debugPrint('NoteitController.syncInitialData error: $e');
      if (isStale(generation) || !ref.mounted) return;
      _cursor = null;
      state = state.copyWith(
        isLoading: false,
        paging: const PagingStatus(hasMore: true, loadMoreFailed: true),
      );
      return;
    }
    await _refreshCount();
  }

  /// Appends the next (older) page; one request at a time, nothing once the
  /// server is exhausted.
  Future<void> loadMore() async {
    final cursor = _cursor;
    if (coupleId == null ||
        sessionUserId == null ||
        !state.paging.hasMore ||
        _loadingMore ||
        cursor == null) {
      return;
    }
    _loadingMore = true;
    final generation = sessionGeneration;
    state = state.copyWith(
      paging: state.paging.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    try {
      final res = await fetchPage(before: cursor, limit: pageSize);
      if (isStale(generation)) return;
      final page = _newestFirst(
        res.map((data) => NoteitItem.fromSupabase(data, sessionUserId!)),
      );
      _cursor = _cursorAfter(page) ?? cursor;
      _pagedCount += page.length;
      final byId = {for (final n in state.notes) n.id: n};
      for (final n in page) {
        byId[n.id] = n;
      }
      state = state.copyWith(
        notes: _newestFirst(byId.values),
        paging: PagingStatus(hasMore: page.length == pageSize),
      );
      await _persistLocalOnly();
    } catch (e) {
      debugPrint('NoteitController.loadMore error: $e');
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

  /// The footer's "Try again".
  Future<void> retryLoad() async {
    if (_cursor == null) {
      _pagedCount = 0;
      await syncInitialData();
      return;
    }
    await loadMore();
  }

  /// Loads the notes with [ids] that aren't loaded yet (e.g. ones older
  /// chat messages refer to) into [NoteitState.detached]. Ids already loaded
  /// or already being fetched are skipped, so calling this on every rebuild
  /// is cheap.
  Future<void> ensureLoaded(Iterable<String> ids) async {
    if (coupleId == null || sessionUserId == null) return;
    final missing = ids
        .where((id) => state.noteById(id) == null && !_idsInFlight.contains(id))
        .toSet()
        .toList();
    if (missing.isEmpty) return;
    _idsInFlight.addAll(missing);
    final generation = sessionGeneration;
    try {
      final rows = await fetchByIds(missing);
      if (isStale(generation) || !ref.mounted) return;
      final detached = {...state.detached};
      for (final row in rows) {
        final note = NoteitItem.fromSupabase(row, sessionUserId!);
        if (state.noteById(note.id) == null) detached[note.id] = note;
      }
      state = state.copyWith(detached: detached);
    } catch (e) {
      debugPrint('NoteitController.ensureLoaded error: $e');
    } finally {
      // Ids that turned out not to exist stay unresolved (the chat shows
      // its placeholder) and may be retried later.
      _idsInFlight.removeAll(missing);
    }
  }

  /// Makes sure every note created in [from, to) is loaded; for Wrapped.
  /// Returns false if the fetch failed.
  Future<bool> ensureRangeLoaded(DateTime from, DateTime to) {
    if (coupleId == null || sessionUserId == null) return Future.value(true);
    final key = '${from.toIso8601String()}|${to.toIso8601String()}';
    return _rangeLoads[key] ??= _loadRange(from, to).whenComplete(() {
      // Block body: remove() returns this very future, and whenComplete
      // waits on whatever its callback returns -- an arrow body deadlocks.
      _rangeLoads.remove(key);
    });
  }

  Future<bool> _loadRange(DateTime from, DateTime to) async {
    final generation = sessionGeneration;
    try {
      final rows = await fetchRange(from, to);
      if (isStale(generation) || !ref.mounted) return false;
      final detached = {...state.detached};
      for (final row in rows) {
        final note = NoteitItem.fromSupabase(row, sessionUserId!);
        detached[note.id] = note;
      }
      state = state.copyWith(detached: detached);
      return true;
    } catch (e) {
      debugPrint('NoteitController.ensureRangeLoaded error: $e');
      return false;
    }
  }

  Future<void> _refreshCount() async {
    if (coupleId == null) return;
    final generation = sessionGeneration;
    try {
      final count = await fetchCount();
      if (isStale(generation) || !ref.mounted) return;
      state = state.copyWith(totalCount: count);
    } catch (e) {
      debugPrint('NoteitController._refreshCount error: $e');
    }
  }

  void _scheduleCountRefresh() {
    _countDebounce?.cancel();
    _countDebounce = Timer(const Duration(milliseconds: 500), () {
      if (ref.mounted) _refreshCount();
    });
  }

  /// Row changes, not the full love_notes table (audit F-18) -- see
  /// LoveChatController.usesRowChanges.
  @override
  bool get usesRowChanges => true;

  @override
  void onRowChange(RowChange change) {
    if (!ref.mounted || sessionUserId == null) return;
    final id = change.id;
    if (id == null) return;
    final inWindow = state.notes.where((n) => n.id == id).firstOrNull;
    final detachedOld = state.detached[id];
    final existing = inWindow ?? detachedOld;
    final others = state.notes.where((n) => n.id != id).toList();
    final isNote =
        change.type != RowChangeType.delete &&
        change.newRecord['type'] != 'chat';

    if (!isNote) {
      // A delete, or a chat row (chat shares the love_notes table).
      if (change.type == RowChangeType.delete) _scheduleCountRefresh();
      if (existing == null) return;
      if (change.type == RowChangeType.delete &&
          !state.isLoading &&
          existing.sender == 'partner') {
        _logPartnerNoteDeleted(existing);
      }
      state = state.copyWith(
        notes: others,
        isLoading: false,
        detached: detachedOld == null
            ? null
            : ({...state.detached}..remove(id)),
      );
    } else {
      final note = NoteitItem.fromSupabase(change.newRecord, sessionUserId!);
      if (existing == null) {
        // An update to a note outside the window arrives with its page;
        // new notes show straight away.
        if (change.type != RowChangeType.insert && state.paging.hasMore) {
          return;
        }
        if (!state.isLoading && note.sender == 'partner') {
          _logPartnerNoteAdded(note);
        }
        _scheduleCountRefresh();
      }
      if (detachedOld != null) {
        state = state.copyWith(detached: {...state.detached, id: note});
      }
      if (inWindow != null || detachedOld == null) {
        state = state.copyWith(
          notes: _newestFirst([note, ...others]),
          isLoading: false,
        );
      }
    }
    _persistLocalOnly();
  }

  void _logPartnerNoteAdded(NoteitItem note) {
    String title = 'Partner sent a love note 💌';
    String desc = 'Shared a new text love note';
    String icon = '✍️';
    String route = 'love_notes';

    if (note.type == NoteitType.drawing) {
      title = 'Partner created a doodle 🎨';
      desc = 'Drew and shared a new doodle';
      icon = '🎨';
      route = 'doodle_notes';
    } else if (note.type == NoteitType.photo) {
      title = 'Partner shared photo note 📸';
      desc = 'Shared a new photo note';
      icon = '📷';
      route = 'love_notes';
    }

    RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: title,
      description: desc,
      icon: icon,
      referenceId: note.id,
      route: route,
    );
  }

  void _logPartnerNoteDeleted(NoteitItem note) {
    RecentActivityService.instance.logActivity(
      activityType: 'deleted',
      title: note.type == NoteitType.drawing
          ? "Partner's doodle deleted 🗑️"
          : "Partner's love note deleted 🗑️",
      description: note.type == NoteitType.drawing
          ? 'Partner deleted a doodle'
          : 'Partner deleted a love note',
      icon: '🗑️',
      referenceId: note.id,
      route: note.type == NoteitType.drawing ? 'doodle_notes' : 'love_notes',
    );
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('NoteitController: Supabase sync error: $error');
    _loadFromCache();
  }

  void updateItemSyncStatus(String id, SyncStatus status) {
    final idx = state.notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final notes = [...state.notes];
    notes[idx] = notes[idx].copyWith(syncStatus: status);
    state = state.copyWith(notes: notes);
    _persistLocalOnly();
  }

  Future<void> sendDrawing(String strokes, Color bgColor) async {
    final newItem = NoteitItem(
      type: NoteitType.drawing,
      content: strokes,
      sender: 'you',
      backgroundColor: bgColor,
      syncStatus: SyncStatus.sending,
    );

    state = state.copyWith(notes: [newItem, ...state.notes]);
    await _persist();

    if (coupleId != null && sessionUserId != null) {
      await NoteitSyncManager.instance.enqueue(
        NoteitSyncTask(
          id: newItem.id,
          type: NoteitType.drawing,
          content: strokes,
          backgroundColor: bgColor,
          createdAt: newItem.createdAt,
        ),
      );
    } else {
      updateItemSyncStatus(newItem.id, SyncStatus.failed);
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Created doodle 🎨',
      description: 'Drew and shared a new doodle',
      icon: '🎨',
      referenceId: newItem.id,
      route: 'doodle_notes',
    );
  }

  Future<void> sendText(String text, Color bgColor) async {
    final newItem = NoteitItem(
      type: NoteitType.text,
      content: text,
      sender: 'you',
      backgroundColor: bgColor,
      syncStatus: SyncStatus.sending,
    );

    state = state.copyWith(notes: [newItem, ...state.notes]);
    await _persist();

    if (coupleId != null && sessionUserId != null) {
      await NoteitSyncManager.instance.enqueue(
        NoteitSyncTask(
          id: newItem.id,
          type: NoteitType.text,
          content: text,
          backgroundColor: bgColor,
          createdAt: newItem.createdAt,
        ),
      );
    } else {
      updateItemSyncStatus(newItem.id, SyncStatus.failed);
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Sent love note 💌',
      description: 'Shared a new text love note',
      icon: '✍️',
      referenceId: newItem.id,
      route: 'love_notes',
    );
  }

  Future<void> sendPhoto(String originalPath) async {
    final noteId = const Uuid().v4();
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'noteit_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newPath = '${directory.path}/$fileName';
      await File(originalPath).copy(newPath);
      if (!ref.mounted) return;

      final newItem = NoteitItem(
        id: noteId,
        type: NoteitType.photo,
        imagePath: newPath,
        sender: 'you',
        syncStatus: SyncStatus.sending,
      );

      state = state.copyWith(notes: [newItem, ...state.notes]);
      await _persist();

      if (coupleId != null && sessionUserId != null) {
        await NoteitSyncManager.instance.enqueue(
          NoteitSyncTask(
            id: noteId,
            type: NoteitType.photo,
            imagePath: newPath,
            createdAt: newItem.createdAt,
          ),
        );
      } else {
        updateItemSyncStatus(noteId, SyncStatus.failed);
      }

      if (!ref.mounted) return;
      await RecentActivityService.instance.logActivity(
        activityType: 'created',
        title: 'Sent photo note 📸',
        description: 'Shared a new photo note',
        icon: '📷',
        referenceId: newItem.id,
        route: 'love_notes',
      );
    } catch (e) {
      debugPrint('NoteitController.sendPhoto failed: $e');
    }
  }

  Future<NoteitItem> sendCanvas(
    String jsonContent,
    String? localImagePath,
  ) async {
    final noteId = const Uuid().v4();
    String? finalLocalPath;

    if (localImagePath != null) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'noteit_canvas_${DateTime.now().millisecondsSinceEpoch}.jpg';
        finalLocalPath = '${directory.path}/$fileName';
        await File(localImagePath).copy(finalLocalPath);
      } catch (e) {
        debugPrint('NoteitController: Failed to copy scrapbook background: $e');
      }
    }

    final newItem = NoteitItem(
      id: noteId,
      type: NoteitType.drawing,
      content: jsonContent,
      imagePath: finalLocalPath,
      sender: 'you',
      syncStatus: SyncStatus.sending,
    );

    if (!ref.mounted) return newItem;
    state = state.copyWith(notes: [newItem, ...state.notes]);
    await _persist();

    if (coupleId != null && sessionUserId != null) {
      await NoteitSyncManager.instance.enqueue(
        NoteitSyncTask(
          id: noteId,
          type: NoteitType.drawing,
          content: jsonContent,
          imagePath: finalLocalPath,
          createdAt: newItem.createdAt,
        ),
      );
    } else {
      updateItemSyncStatus(noteId, SyncStatus.failed);
    }

    if (ref.mounted) {
      await RecentActivityService.instance.logActivity(
        activityType: 'created',
        title: 'Created scrapbook canvas note 🎨',
        description: 'Shared an interactive scrapbook canvas note',
        icon: '🎨',
        referenceId: noteId,
        route: 'doodle_notes',
      );
    }

    return newItem;
  }

  Future<void> deleteNote(String id) async {
    // Not noteById: that hides everything while unpaired, and local-only
    // notes must still be deletable then.
    final noteToDelete =
        state.notes.where((n) => n.id == id).firstOrNull ?? state.detached[id];
    if (noteToDelete == null) return;
    if (noteToDelete.imagePath != null) {
      try {
        final file = File(noteToDelete.imagePath!);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('NoteitController: Failed to delete image file: $e');
      }
    }

    if (coupleId != null) {
      try {
        await Supabase.instance.client
            .from(Tables.loveNotes)
            .delete()
            .eq('id', id);

        if (noteToDelete.type == NoteitType.photo) {
          try {
            final storagePath = 'couples/$coupleId/love_notes/$id.jpg';
            await Supabase.instance.client.storage
                .from(StorageBuckets.loveNotes)
                .remove([storagePath]);
          } catch (e) {
            debugPrint('NoteitController.deleteNote storage remove error: $e');
          }
        }
      } catch (e) {
        debugPrint('NoteitController.deleteNote Supabase error: $e');
        if (!ref.mounted) return;
        _removeLocally(id);
        await _persist();
      }
    } else {
      _removeLocally(id);
      await _persist();
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'deleted',
      title: noteToDelete.type == NoteitType.drawing
          ? 'Doodle deleted 🗑️'
          : 'Love note deleted 🗑️',
      description: noteToDelete.type == NoteitType.drawing
          ? 'Deleted a doodle'
          : 'Deleted a love note',
      icon: '🗑️',
      referenceId: id,
      route: noteToDelete.type == NoteitType.drawing
          ? 'doodle_notes'
          : 'love_notes',
    );
  }

  void _removeLocally(String id) {
    state = state.copyWith(
      notes: state.notes.where((n) => n.id != id).toList(),
      detached: {...state.detached}..remove(id),
    );
  }

  String _generateHeartStrokes() {
    final List<List<Offset>> strokes = [];
    final List<Offset> stroke = [];
    for (double t = 0; t <= 2 * pi; t += 0.08) {
      double x = 150 + 70 * pow(sin(t), 3).toDouble();
      double y =
          150 -
          (55 * cos(t) - 22 * cos(2 * t) - 9 * cos(3 * t) - 4 * cos(4 * t));
      stroke.add(Offset(x, y));
    }
    strokes.add(stroke);
    return _serializeStrokes(strokes);
  }

  String _serializeStrokes(List<List<Offset>> strokes) {
    return strokes
        .map(
          (stroke) => stroke
              .map(
                (p) => '${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}',
              )
              .join(';'),
        )
        .join('|');
  }

  Future<void> _persist() => _persistLocalOnly();

  Future<void> _persistLocalOnly() async {
    try {
      final jsonList = state.notes.map((n) => n.toJson()).toList();
      await _cache.write(jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('NoteitController._persistLocalOnly failed: $e\n$st');
    }
  }
}

/// Keyset position in the scrapbook's (created_at, id) newest-first order.
typedef NoteitCursor = ({DateTime createdAt, String id});

final noteitControllerProvider =
    NotifierProvider.autoDispose<NoteitController, NoteitState>(
      NoteitController.new,
      dependencies: [coupleSessionProvider],
    );
