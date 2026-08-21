import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/features/settings/notification_preferences_state.dart';
import 'package:days_together/models/notification_preferences_model.dart';
import 'package:days_together/providers/couple_session.dart';

/// Riverpod port of `NotificationPreferencesProvider` (Phase 6a of the
/// architecture migration, the twelfth and last of the 12 domain
/// providers). Structurally different from the other 11: it extends the
/// original's `RelationshipLifecycleProvider` base (no realtime
/// subscription at all, confirmed during this phase's investigation), and
/// is keyed on `userId` alone, not `coupleId` -- `user_notification_preferences`
/// is a per-user table, not a per-couple one. Does not use
/// `SupabaseLifecycleNotifier` (that mixin's `tableName`/`initRealtime`
/// contract has nothing to hook into here); instead reproduces
/// `RelationshipLifecycleProvider`'s own smaller `updateSession` contract
/// directly.
///
/// **Preserved, non-obvious gating:** the original base class's
/// `updateSession` only calls `syncInitialData()` when *both*
/// `coupleId` and `userId` are non-null, even though this provider's own
/// logic only ever reads `userId`. This means a signed-in-but-unpaired user
/// never has their notification preferences loaded until pairing completes
/// -- almost certainly an accident of inheriting the base class unchanged
/// rather than a deliberate design choice, but preserved exactly rather
/// than "fixed," since Phase 6a's job is a faithful port.
class NotificationPreferencesController extends Notifier<NotificationPreferencesState> {
  static const _syncTimeout = Duration(seconds: 15);

  String? _coupleId;
  String? _userId;

  @override
  NotificationPreferencesState build() {
    final session = ref.read(coupleSessionProvider);
    _coupleId = session.coupleId;
    _userId = session.userId;
    if (_coupleId != null && _userId != null) {
      _runSyncInitialData();
    }
    return const NotificationPreferencesState();
  }

  void _runSyncInitialData() {
    syncInitialData().timeout(
      _syncTimeout,
      onTimeout: () => debugPrint('NotificationPreferencesController: syncInitialData timed out'),
    );
  }

  Future<void> updateSession(CoupleSession session) async {
    final credentialsChanged = _coupleId != session.coupleId || _userId != session.userId;
    if (!credentialsChanged) return;

    _coupleId = session.coupleId;
    _userId = session.userId;

    if (_coupleId != null && _userId != null) {
      try {
        await syncInitialData().timeout(_syncTimeout);
      } on TimeoutException {
        debugPrint('NotificationPreferencesController: syncInitialData timed out');
      }
    } else {
      await purgeCache();
    }
  }

  Future<void> purgeCache() async {
    state = const NotificationPreferencesState();
  }

  Future<void> syncInitialData() async {
    if (_userId != null) {
      await _loadPreferences(_userId!);
    }
  }

  Future<void> _loadPreferences(String userId) async {
    state = state.copyWith(isLoading: true);

    try {
      final client = Supabase.instance.client;
      final res = await client.from('user_notification_preferences').select().eq('user_id', userId).maybeSingle();

      if (!ref.mounted) return;

      NotificationPreferences preferences;
      if (res != null) {
        preferences = NotificationPreferences.fromJson(res);
        final localTz = DateTime.now().timeZoneName;
        if (preferences.timezone != localTz) {
          state = state.copyWith(preferences: preferences, isLoading: false);
          await updatePreference('timezone', localTz);
          return;
        }
      } else {
        preferences = NotificationPreferences(userId: userId, timezone: DateTime.now().timeZoneName);
        await client.from('user_notification_preferences').insert(preferences.toJson());
      }

      if (!ref.mounted) return;
      state = state.copyWith(preferences: preferences, isLoading: false);
    } catch (e) {
      debugPrint('NotificationPreferencesController: Error loading preferences: $e');
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updatePreference(String key, dynamic value) async {
    final current = state.preferences;
    if (current == null) return;

    final updatedJson = current.toJson();
    updatedJson[key] = value;
    updatedJson['updated_at'] = DateTime.now().toUtc().toIso8601String();

    try {
      final client = Supabase.instance.client;
      await client.from('user_notification_preferences').upsert(updatedJson);

      if (!ref.mounted) return;
      state = state.copyWith(preferences: NotificationPreferences.fromJson(updatedJson));
    } catch (e) {
      debugPrint('NotificationPreferencesController: Error updating preference $key: $e');
    }
  }

  Future<void> togglePreference(String key) async {
    final current = state.preferences;
    if (current == null) return;
    final currentJson = current.toJson();
    final currentValue = currentJson[key];
    if (currentValue is bool) {
      await updatePreference(key, !currentValue);
    }
  }
}

final notificationPreferencesControllerProvider =
    NotifierProvider.autoDispose<NotificationPreferencesController, NotificationPreferencesState>(
  NotificationPreferencesController.new,
  dependencies: [coupleSessionProvider],
);
