import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:days_together/services/supabase_sync_service.dart';

/// A centralized manager to multiplex real-time Supabase subscriptions.
/// Prevents duplicate streams to the same table by sharing a single broadcast stream.
class RealtimeSubscriptionManager {
  RealtimeSubscriptionManager._();

  /// Singleton instance of the manager.
  static final RealtimeSubscriptionManager instance = RealtimeSubscriptionManager._();

  // Active broadcast streams keyed by 'tableName_coupleId'
  final Map<String, Stream<List<Map<String, dynamic>>>> _streams = {};

  // Active source subscriptions to clean up when no listeners remain
  final Map<String, StreamSubscription<List<Map<String, dynamic>>>> _sourceSubscriptions = {};

  /// Retrieves a shared broadcast stream for the given table and couple ID.
  /// If no stream is active, establishing connection to Supabase Realtime.
  Stream<List<Map<String, dynamic>>> getStream({
    required String tableName,
    required String coupleId,
    List<String> primaryKey = const ['id'],
  }) {
    final key = '${tableName}_$coupleId';

    if (_streams.containsKey(key)) {
      return _streams[key]!;
    }

    late final StreamController<List<Map<String, dynamic>>> controller;

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        debugPrint('RealtimeSubscriptionManager: Establishing connection for $tableName (Couple: $coupleId)');
        final subscription = SupabaseSyncService.instance.subscribeToCoupleData(
          tableName: tableName,
          coupleId: coupleId,
          primaryKey: primaryKey,
          onData: (data) {
            if (!controller.isClosed) {
              controller.add(data);
            }
          },
          onError: (error) {
            if (!controller.isClosed) {
              controller.addError(error);
            }
          },
        );

        _sourceSubscriptions[key] = subscription;
      },
      onCancel: () {
        debugPrint('RealtimeSubscriptionManager: Tearing down connection for $tableName (Couple: $coupleId)');
        _sourceSubscriptions[key]?.cancel();
        _sourceSubscriptions.remove(key);
        _streams.remove(key);
        controller.close();
      },
    );

    _streams[key] = controller.stream;
    return controller.stream;
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

  /// The number of distinct table+couple keys with an active shared
  /// subscription right now. For regression tests asserting teardown
  /// behavior (Definition-of-Done item 19) without reaching into private
  /// state.
  @visibleForTesting
  int get activeStreamCount => _streams.length;
}
