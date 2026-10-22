import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/core/network/realtime_subscription_manager.dart';
import 'package:days_together/core/network/row_change.dart';

/// The Riverpod-native replacement for `SupabaseLifecycleProvider`/
/// `RelationshipLifecycleProvider` (`lib/services/relationship_lifecycle_manager.dart`),
/// mixed into a couple-scoped `Notifier` subclass (Phase 6a of the
/// architecture migration).
///
/// `autoDispose` (declared on the provider, e.g.
/// `NotifierProvider.autoDispose<X, XState>(X.new)`) replaces the old base
/// class's `hasListeners`-gated `addListener`/`removeListener` refcounting
/// for realtime subscriptions -- when the last widget watching the provider
/// unmounts, Riverpod tears the whole notifier down, which (via
/// [initSessionLifecycle]'s `ref.onDispose(disposeRealtime)`) cancels the
/// realtime subscription too, matching the old "no listeners -> no
/// subscription" behavior. REST sync (unlike realtime) still runs
/// unconditionally on every credentials change regardless of whether
/// anything is currently watching -- matching the old
/// `RelationshipLifecycleProvider.updateSession`'s unconditional
/// `syncInitialData()` call -- since a not-currently-watched but
/// `autoDispose`d provider still runs [updateSession] synchronously when
/// poked (see `main.dart`'s `_DomainProvidersBridge`), then gets disposed
/// shortly after if nothing watches it, discarding the realtime
/// subscription but not the SharedPreferences cache the sync already wrote.
///
/// Session-change propagation is a `main.dart`-level bridge widget
/// (`_DomainProvidersBridge`, mirroring Phase 5's `_ProfileControllerBridge`
/// et al.) calling [updateSession] on every `CoupleSession` change, rather
/// than each notifier reactively `ref.watch`ing `coupleSessionProvider` --
/// that provider is a one-shot bridge onto the live Provider-package
/// `CoupleSession` instance (Phase 2's strangler bridge), not itself
/// Riverpod-reactive, so an explicit push is how Phase 5's four mirror
/// controllers already get session-change notifications, and this repeats
/// that established, working pattern rather than introducing a new one.
mixin SupabaseLifecycleNotifier<T> on Notifier<T> {
  static const _syncTimeout = Duration(seconds: 15);

  /// How long a row-change controller waits for its feed to go live before
  /// loading its snapshot anyway (see [initRealtime]).
  static const _rowFeedFallback = Duration(seconds: 5);

  /// The Supabase table this notifier's realtime subscription watches.
  String get tableName;
  List<String> get primaryKey => const ['id'];

  String? _coupleId;
  String? _userId;
  StreamSubscription<Object?>? _syncSub;

  String? get coupleId => _coupleId;
  String? get sessionUserId => _userId;

  /// Bumped on every credentials change (user or couple). An async load
  /// captures it before its first await and checks [isStale] before writing
  /// [state] or the cache, so a response for the PREVIOUS user/couple that
  /// lands after an account switch, unlink or logout is dropped instead of
  /// overwriting the newer state -- including the empty state purgeCache()
  /// just set (audit F-15).
  int _sessionGeneration = 0;
  int get sessionGeneration => _sessionGeneration;

  /// True once [generation] no longer describes the current session (or the
  /// notifier was disposed). See [sessionGeneration].
  bool isStale(int generation) =>
      !ref.mounted || generation != _sessionGeneration;

  /// Consecutive times the realtime stream ended without delivering data;
  /// drives the resubscribe backoff in [_onRealtimeDone].
  int _realtimeRestarts = 0;

  /// REST-fetches this feature's couple-scoped data and updates [state].
  /// Called on every `credentialsChanged` transition into a paired state,
  /// and once eagerly from [initSessionLifecycle] if already paired at
  /// creation time.
  Future<void> syncInitialData();

  /// Clears in-memory and SharedPreferences-cached state. Called on every
  /// `credentialsChanged` transition into an unpaired state (disconnect,
  /// logout).
  Future<void> purgeCache();

  /// A realtime payload arrived for [tableName]: the FULL matching row list
  /// (`.stream()`). Implementations update [state] and persist to the local
  /// cache. Unused by controllers that opt into [usesRowChanges].
  void onRealtimeData(List<Map<String, dynamic>> dataList) {}
  void onRealtimeError(Object error) {}

  /// Opt in to individual row changes instead of the full-list stream
  /// (audit F-18): the controller keeps the bounded snapshot its
  /// [syncInitialData] loads and applies each change in [onRowChange]. Use it
  /// where re-fetching and re-emitting every row is expensive (love_notes).
  bool get usesRowChanges => false;

  /// One row changed (see [usesRowChanges]). Never receives
  /// [RowChangeType.ready]: the mixin answers that by (re)running
  /// [syncInitialData].
  void onRowChange(RowChange change) {}

  /// Call once from the concrete class's `build()`. Registers realtime
  /// teardown on dispose and, if a couple is already known at creation time
  /// (the common case -- domain screens are only reachable once paired),
  /// kicks off the initial sync and subscription immediately.
  ///
  /// [initRealtime] itself is deferred to a microtask, not called
  /// synchronously here: `build()` hasn't returned its initial `state` value
  /// yet at this point, and at least one override ([TopicCardsController]'s)
  /// writes `state` as the first thing it does. Writing (or reading) `state`
  /// before `build()` has returned throws Riverpod's "Tried to read the
  /// state of an uninitialized provider" -- found via a manual on-device
  /// smoke test reproducing it on the very first screen shown right after
  /// creating a workspace, since that's exactly when a domain controller can
  /// first build with `coupleId`/`userId` already known synchronously. A
  /// microtask runs strictly after the current synchronous call stack
  /// (including `build()`'s own return) completes, so `state` is always
  /// safe to touch by the time `initRealtime()` actually runs -- with
  /// negligible added latency, well before the next frame.
  void initSessionLifecycle() {
    ref.onDispose(disposeRealtime);
    final session = ref.read(coupleSessionProvider);
    _coupleId = session.coupleId;
    _userId = session.userId;
    if (_coupleId != null && _userId != null) {
      final rowFeed = usesRowChanges && session.isSupabaseAvailable;
      // A row-change controller loads its snapshot when its feed goes live
      // (see initRealtime); everything else loads now.
      if (!rowFeed) _runSyncInitialData();
      if (session.isSupabaseAvailable) {
        Future.microtask(() {
          if (ref.mounted) initRealtime();
        });
      }
    }
  }

  void _runSyncInitialData() {
    syncInitialData().timeout(
      _syncTimeout,
      onTimeout: () {
        debugPrint(
          '$runtimeType: syncInitialData timed out after ${_syncTimeout.inSeconds}s',
        );
      },
    );
  }

  void initRealtime() {
    if (_coupleId == null) return;
    _syncSub?.cancel();
    final generation = _sessionGeneration;
    if (usesRowChanges) {
      // Subscribe FIRST, load the snapshot once the feed is live: Realtime
      // drops changes committed before Postgres confirms the subscription, so
      // a snapshot taken any earlier can miss them (RowChangeType.ready).
      var snapshotTaken = false;
      void takeSnapshot() {
        if (isStale(generation)) return;
        snapshotTaken = true;
        _runSyncInitialData();
      }

      final manager = RealtimeSubscriptionManager.instance;
      _syncSub = manager
          .getRowChanges(tableName: tableName, coupleId: _coupleId!)
          .listen(
            (change) {
              _realtimeRestarts = 0;
              if (change.type == RowChangeType.ready) {
                takeSnapshot(); // first connect, or after a reconnect
              } else {
                onRowChange(change);
              }
            },
            onError: onRealtimeError,
            onDone: () => _onRealtimeDone(generation),
          );
      // Shared feed already live (another controller opened it): no ready
      // event will come for us, so load now.
      if (manager.isRowChangesReady(
        tableName: tableName,
        coupleId: _coupleId!,
      )) {
        takeSnapshot();
      }
      // Realtime down or slow to confirm: never leave the screen without its
      // snapshot.
      Future.delayed(_rowFeedFallback, () {
        if (!snapshotTaken) takeSnapshot();
      });
      return;
    }
    _syncSub = RealtimeSubscriptionManager.instance
        .getStream(
          tableName: tableName,
          coupleId: _coupleId!,
          primaryKey: primaryKey,
        )
        .listen(
          (rows) {
            _realtimeRestarts = 0;
            onRealtimeData(rows);
          },
          onError: onRealtimeError,
          onDone: () => _onRealtimeDone(generation),
        );
  }

  /// The shared stream ended: its channel was closed underneath it -- by
  /// CoupleSession's removeAllChannels() on an auth change, or by the server.
  /// Before this was handled, the subscription stayed referenced but silent
  /// and [updateSession] never re-subscribed, so live updates stopped until
  /// the app restarted (audit F-16). Re-subscribe after a short backoff, for
  /// the same session only.
  void _onRealtimeDone(int generation) {
    if (isStale(generation)) return;
    _syncSub = null;
    final delay = Duration(
      seconds: 1 << (_realtimeRestarts < 6 ? _realtimeRestarts : 6),
    );
    _realtimeRestarts++;
    Future.delayed(delay, () {
      if (isStale(generation) || _syncSub != null) return;
      if (ref.read(coupleSessionProvider).isSupabaseAvailable) {
        initRealtime();
      }
    });
  }

  void disposeRealtime() {
    _syncSub?.cancel();
    _syncSub = null;
  }

  /// Called from `main.dart`'s `_DomainProvidersBridge` on every
  /// `CoupleSession` change -- the Riverpod-native equivalent of
  /// `RelationshipLifecycleProvider.updateSession`.
  Future<void> updateSession(CoupleSession session) async {
    final credentialsChanged =
        _coupleId != session.coupleId || _userId != session.userId;

    if (credentialsChanged) {
      _coupleId = session.coupleId;
      _userId = session.userId;
      _sessionGeneration++;
      _realtimeRestarts = 0;
      disposeRealtime();

      if (_coupleId != null && _userId != null) {
        if (usesRowChanges && session.isSupabaseAvailable) {
          // Snapshot loads when the feed is live -- see initRealtime.
          initRealtime();
          return;
        }
        try {
          await syncInitialData().timeout(_syncTimeout);
        } on TimeoutException {
          debugPrint(
            '$runtimeType: syncInitialData timed out after ${_syncTimeout.inSeconds}s',
          );
        }
        // syncInitialData is implemented by the concrete class and may have
        // awaited a network call; this autoDispose notifier could have been
        // torn down in the meantime if nothing was watching it. Starting a
        // realtime subscription on a disposed notifier would leak it, since
        // ref.onDispose's cancellation hook has already fired and won't run
        // again.
        if (!ref.mounted) return;
        if (session.isSupabaseAvailable) initRealtime();
      } else {
        await purgeCache();
      }
    } else if (session.isSupabaseAvailable &&
        _syncSub == null &&
        _coupleId != null) {
      initRealtime();
    }
  }
}
