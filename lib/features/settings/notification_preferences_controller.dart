import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/errors/app_failure.dart';
import 'package:days_together/features/settings/data/notification_preferences_cache.dart';

import 'package:days_together/features/settings/notification_preferences_state.dart';
import 'package:days_together/features/settings/domain/entities/notification_preferences_model.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/core/constants/tables.dart';

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
/// **Gating, since corrected:** the original base class's `updateSession`
/// only ran `syncInitialData()` when *both* `coupleId` and `userId` were
/// non-null, even though this controller's logic only ever reads `userId`
/// -- `user_notification_preferences` is a per-user table. A
/// signed-in-but-unpaired user therefore never loaded their preferences at
/// all, and the settings screen sat on its spinner forever. Phase 6a
/// preserved that verbatim because its job was a faithful port; it is now
/// gated on `userId` alone. `coupleId` is still tracked, purely so that
/// pairing counts as a credentials change and triggers a refresh.
///
/// **Local cache:** preferences are mirrored on device by
/// [NotificationPreferencesCache], so reopening the screen paints the
/// last-known values immediately instead of showing a spinner while a
/// network round-trip completes -- this controller is `autoDispose`, so
/// without the mirror every visit started from an empty state. The cache is
/// keyed per user; see that class for why, and for why it is a separate
/// object rather than inline methods here.
class NotificationPreferencesController
    extends Notifier<NotificationPreferencesState> {
  static const _syncTimeout = Duration(seconds: 15);
  static const NotificationPreferencesCache _cache =
      NotificationPreferencesCache();

  String? _coupleId;
  String? _userId;

  @override
  NotificationPreferencesState build() {
    final session = ref.read(coupleSessionProvider);
    _coupleId = session.coupleId;
    _userId = session.userId;
    // Paint the cached values first, then refresh from Supabase.
    _loadFromCache();
    if (_userId != null) {
      Future.microtask(_runSyncInitialData);
    }
    return const NotificationPreferencesState();
  }

  /// Seeds state from this user's last-known preferences so the settings
  /// screen has something to render on the first frame. Deliberately does
  /// not set `isLoading`: the cached values are real, and the refresh behind
  /// them is not something the user needs to wait on.
  Future<void> _loadFromCache() async {
    final userId = _userId;
    if (userId == null) return;
    final cached = await _cache.load(userId);
    if (cached == null || !ref.mounted) return;
    // A completed network load wins over the cache if it got there first.
    if (state.preferences != null) return;
    state = state.copyWith(preferences: cached);
  }

  void _runSyncInitialData() {
    syncInitialData().timeout(
      _syncTimeout,
      onTimeout: () => debugPrint(
        'NotificationPreferencesController: syncInitialData timed out',
      ),
    );
  }

  Future<void> updateSession(CoupleSession session) async {
    final credentialsChanged =
        _coupleId != session.coupleId || _userId != session.userId;
    if (!credentialsChanged) return;

    _coupleId = session.coupleId;
    _userId = session.userId;

    if (_userId != null) {
      try {
        await syncInitialData().timeout(_syncTimeout);
      } on TimeoutException {
        debugPrint(
          'NotificationPreferencesController: syncInitialData timed out',
        );
      }
    } else {
      await purgeCache();
    }
  }

  Future<void> purgeCache() async {
    await _cache.clearAll();
    if (!ref.mounted) return;
    state = const NotificationPreferencesState();
  }

  Future<void> syncInitialData() async {
    if (_userId != null) {
      await _loadPreferences(_userId!);
    }
  }

  Future<void> _loadPreferences(String userId) async {
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: true);

    try {
      final client = Supabase.instance.client;
      final res = await client
          .from(Tables.userNotificationPreferences)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (!ref.mounted) return;

      String? localTz;
      try {
        localTz = (await FlutterTimezone.getLocalTimezone()).identifier;
      } catch (e) {
        // Keep the stored value when the platform cannot supply an IANA id.
        // DateTime.timeZoneName is not a safe fallback: it can be an
        // abbreviation rejected by the notification function.
        debugPrint(
          'NotificationPreferencesController: timezone lookup failed: $e',
        );
      }
      if (!ref.mounted) return;

      NotificationPreferences preferences;
      if (res != null) {
        preferences = NotificationPreferences.fromJson(res);
        if (localTz != null && preferences.timezone != localTz) {
          state = state.copyWith(preferences: preferences, isLoading: false);
          await updatePreference('timezone', localTz);
          return;
        }
      } else {
        preferences = NotificationPreferences(
          userId: userId,
          timezone: localTz ?? 'UTC',
        );
        await client
            .from(Tables.userNotificationPreferences)
            .insert(preferences.toJson());
      }

      if (!ref.mounted) return;
      state = state.copyWith(preferences: preferences, isLoading: false);
      await _cache.save(userId, preferences);
    } catch (e) {
      debugPrint(
        'NotificationPreferencesController: Error loading preferences: $e',
      );
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
      await client.from(Tables.userNotificationPreferences).upsert(updatedJson);

      if (!ref.mounted) return;
      final updated = NotificationPreferences.fromJson(updatedJson);
      state = state.copyWith(preferences: updated, failure: null);
      final userId = _userId;
      if (userId != null) await _cache.save(userId, updated);
    } catch (e) {
      debugPrint(
        'NotificationPreferencesController: Error updating preference $key: $e',
      );
      if (!ref.mounted) return;
      // The write ran before the local state update, so `state.preferences`
      // still holds the pre-toggle values and the switch stays where it was.
      // Publishing the failure is what lets the screen say so, instead of
      // the tap looking like it simply did nothing.
      state = state.copyWith(failure: mapExceptionToFailure(e));
    }
  }

  /// Drops the last write failure. Called by the UI once it has shown it, so
  /// the same error is not surfaced twice.
  void clearFailure() {
    if (!ref.mounted) return;
    if (state.failure == null) return;
    state = state.copyWith(failure: null);
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
    NotifierProvider.autoDispose<
      NotificationPreferencesController,
      NotificationPreferencesState
    >(
      NotificationPreferencesController.new,
      dependencies: [coupleSessionProvider],
    );
