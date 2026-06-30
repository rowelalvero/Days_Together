import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
              debugPrint('SupabaseSyncService: stream error on $tableName: $err');
              onError(err);
            },
          );
    } catch (e) {
      debugPrint('SupabaseSyncService: failed to subscribe to $tableName: $e');
      onError(e);
      // Return a dummy empty subscription to prevent null dereferences
      return const Stream<List<Map<String, dynamic>>>.empty().listen(onData);
    }
  }
}
