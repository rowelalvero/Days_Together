import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:days_together/core/network/row_change.dart';
import 'package:days_together/core/network/supabase_sync_service.dart';

/// A centralized manager to multiplex real-time Supabase subscriptions.
/// Prevents duplicate streams to the same table by sharing a single broadcast stream.
///
/// Two kinds of shared stream, with identical lifecycle rules (opened on the
/// first listener, torn down on the last, ended on [reset] or when the
/// underlying channel closes):
/// * [getStream] -- the full matching row list, via `.stream()`.
/// * [getRowChanges] -- individual row changes (audit F-18; see [RowChange]).
class RealtimeSubscriptionManager {
  RealtimeSubscriptionManager._();

  /// Singleton instance of the manager.
  static final RealtimeSubscriptionManager instance =
      RealtimeSubscriptionManager._();

  // Active broadcast streams, keyed by kind + table + couple.
  final Map<String, Stream<Object?>> _streams = {};

  // The controller behind each key, so [reset] / a finished source can close
  // it.
  final Map<String, StreamController<Object?>> _controllers = {};

  // How to tear down each key's underlying source subscription/channel.
  final Map<String, void Function()> _sourceClosers = {};

  // Row-change keys whose Postgres change feed is currently live.
  final Set<String> _readyKeys = {};

  /// Whether the shared row-change feed for [tableName]/[coupleId] is live
  /// right now -- for a listener attaching after its [RowChangeType.ready].
  bool isRowChangesReady({
    required String tableName,
    required String coupleId,
  }) => _readyKeys.contains('rows:${tableName}_$coupleId');

  /// Retrieves a shared broadcast stream for the given table and couple ID.
  /// If no stream is active, establishing connection to Supabase Realtime.
  Stream<List<Map<String, dynamic>>> getStream({
    required String tableName,
    required String coupleId,
    List<String> primaryKey = const ['id'],
  }) {
    final key = '${tableName}_$coupleId';
    return _shared<List<Map<String, dynamic>>>(key, tableName, coupleId, (
      controller,
    ) {
      final subscription = SupabaseSyncService.instance.subscribeToCoupleData(
        tableName: tableName,
        coupleId: coupleId,
        primaryKey: primaryKey,
        onData: (data) {
          if (!controller.isClosed) controller.add(data);
        },
        onError: (error) {
          if (!controller.isClosed) controller.addError(error);
        },
        // The source ends when its channel is closed underneath it
        // (removeAllChannels() on an auth change, or the server). Forward
        // that and forget the key, so listeners learn they must re-subscribe
        // and the next getStream() opens a live channel instead of returning
        // this dead one (audit F-16).
        onDone: () => _retire(key, controller),
      );
      return subscription.cancel;
    });
  }

  /// A shared stream of individual row changes for [tableName] rows of
  /// [coupleId]. Emits [RowChangeType.ready] each time the change feed goes
  /// live (first connect and every reconnect); a listener that attaches to a
  /// feed that is already live checks [isRowChangesReady] instead.
  Stream<RowChange> getRowChanges({
    required String tableName,
    required String coupleId,
  }) {
    final key = 'rows:${tableName}_$coupleId';
    return _shared<RowChange>(key, tableName, coupleId, (controller) {
      return SupabaseSyncService.instance.subscribeToCoupleRowChanges(
        tableName: tableName,
        coupleId: coupleId,
        onChange: (change) {
          if (!controller.isClosed) controller.add(change);
        },
        onSubscribed: () {
          _readyKeys.add(key);
          if (!controller.isClosed) controller.add(const RowChange.ready());
        },
        onError: (error) {
          if (!controller.isClosed) controller.addError(error);
        },
        onClosed: () => _retire(key, controller),
      );
    });
  }

  Stream<T> _shared<T>(
    String key,
    String tableName,
    String coupleId,
    void Function() Function(StreamController<T> controller) open,
  ) {
    final existing = _streams[key];
    if (existing != null) return existing.cast<T>();

    late final StreamController<T> controller;
    controller = StreamController<T>.broadcast(
      onListen: () {
        debugPrint(
          'RealtimeSubscriptionManager: Establishing connection for $key (Couple: $coupleId)',
        );
        _sourceClosers[key] = open(controller);
      },
      onCancel: () {
        debugPrint(
          'RealtimeSubscriptionManager: Tearing down connection for $key (Couple: $coupleId)',
        );
        _retire(key, controller);
      },
    );

    _controllers[key] = controller;
    _streams[key] = controller.stream;
    return controller.stream;
  }

  void _retire(String key, StreamController<Object?> controller) {
    _readyKeys.remove(key);
    _sourceClosers.remove(key)?.call();
    if (identical(_controllers[key], controller)) {
      _controllers.remove(key);
      _streams.remove(key);
    }
    if (!controller.isClosed) controller.close();
  }

  /// Ends every shared stream. Call right after
  /// `Supabase.instance.client.removeAllChannels()`: that kills every
  /// underlying channel at once, and each listener must hear about it (via
  /// onDone) to re-subscribe on a fresh channel.
  void reset() {
    for (final key in _controllers.keys.toList()) {
      _retire(key, _controllers[key]!);
    }
  }

  /// Whether a shared subscription for this table+couple key is currently
  /// active (i.e. has at least one listener). `Stream.broadcast()`'s own
  /// `.stream` getter mints a fresh wrapper object on every access, so two
  /// `getStream()` calls for the same key are never `identical()` even
  /// though they deliver from the same underlying controller -- this is
  /// the key-presence check the identity comparison can't give a test.
  @visibleForTesting
  bool hasActiveStream({required String tableName, required String coupleId}) {
    return _streams.containsKey('${tableName}_$coupleId');
  }

  @visibleForTesting
  bool hasActiveRowChanges({
    required String tableName,
    required String coupleId,
  }) {
    return _streams.containsKey('rows:${tableName}_$coupleId');
  }

  /// The number of distinct keys with an active shared subscription right
  /// now. For regression tests asserting teardown behavior
  /// (Definition-of-Done item 19) without reaching into private state.
  @visibleForTesting
  int get activeStreamCount => _streams.length;
}
