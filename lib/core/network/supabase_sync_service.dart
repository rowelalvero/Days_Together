import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/core/network/row_change.dart';

/// A centralized service for managing real-time database stream subscriptions.
class SupabaseSyncService {
  SupabaseSyncService._();

  /// The singleton instance of the sync service.
  static final SupabaseSyncService instance = SupabaseSyncService._();

  /// Subscribes to a Supabase real-time stream filtered by a given couple ID.
  ///
  /// Listens to events and delegates updates to [onData] and errors to [onError].
  StreamSubscription<List<Map<String, dynamic>>> subscribeToCoupleData({
    required String tableName,
    required String coupleId,
    required void Function(List<Map<String, dynamic>> data) onData,
    required void Function(Object error) onError,
    void Function()? onDone,
    List<String> primaryKey = const ['id'],
  }) {
    try {
      return Supabase.instance.client
          .from(tableName)
          .stream(primaryKey: primaryKey)
          .eq('couple_id', coupleId)
          .listen(
            onData,
            onError: (err) {
              debugPrint(
                'SupabaseSyncService: stream error on $tableName: $err',
              );
              onError(err);
            },
            onDone: onDone,
          );
    } catch (e) {
      debugPrint('SupabaseSyncService: failed to subscribe to $tableName: $e');
      onError(e);
      // Return a dummy empty subscription to prevent null dereferences
      return const Stream<List<Map<String, dynamic>>>.empty().listen(onData);
    }
  }

  /// Subscribes to individual INSERT/UPDATE/DELETE changes on [tableName]
  /// rows of [coupleId] -- no initial snapshot, no full-list re-emission
  /// (audit F-18; see RowChange). Postgres RLS still decides what each
  /// subscriber receives.
  ///
  /// [onSubscribed] fires each time the Postgres change feed becomes live --
  /// Realtime's "Subscribed to PostgreSQL" system message, which arrives
  /// seconds AFTER the channel's SUBSCRIBED status; changes committed before
  /// it are never delivered. The caller (re)loads its snapshot then.
  /// [onClosed] fires when the channel is closed (e.g. removeAllChannels()).
  ///
  /// Returns a function that tears the channel down.
  Future<void> Function() subscribeToCoupleRowChanges({
    required String tableName,
    required String coupleId,
    required void Function(RowChange change) onChange,
    required void Function() onSubscribed,
    required void Function(Object error) onError,
    required void Function() onClosed,
    @visibleForTesting SupabaseClient? client,
  }) {
    try {
      client ??= Supabase.instance.client;
      final channel = client
          .channel('rows:$tableName:$coupleId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: tableName,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'couple_id',
              value: coupleId,
            ),
            callback: (payload) {
              final type = switch (payload.eventType) {
                PostgresChangeEvent.insert => RowChangeType.insert,
                PostgresChangeEvent.update => RowChangeType.update,
                PostgresChangeEvent.delete => RowChangeType.delete,
                PostgresChangeEvent.all => null,
              };
              if (type == null) return;
              onChange(
                RowChange(
                  type: type,
                  newRecord: payload.newRecord,
                  oldRecord: payload.oldRecord,
                ),
              );
            },
          )
          .onSystemEvents((payload) {
            if (payload['extension'] != 'postgres_changes') return;
            if (payload['status'] == 'ok') {
              onSubscribed();
            } else {
              onError(payload['message'] ?? payload);
            }
          })
          .subscribe((status, [error]) {
            switch (status) {
              case RealtimeSubscribeStatus.subscribed:
                break; // Not yet live -- see onSubscribed.
              case RealtimeSubscribeStatus.closed:
                onClosed();
              case RealtimeSubscribeStatus.channelError:
              case RealtimeSubscribeStatus.timedOut:
                debugPrint(
                  'SupabaseSyncService: row channel $tableName $status: $error',
                );
                onError(error ?? status);
            }
          });
      final owner = client;
      return () async {
        await owner.removeChannel(channel);
      };
    } catch (e) {
      debugPrint(
        'SupabaseSyncService: failed to subscribe to $tableName rows: $e',
      );
      onError(e);
      return () async {};
    }
  }
}
