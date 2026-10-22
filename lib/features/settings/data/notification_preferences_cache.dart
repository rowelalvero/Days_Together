import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/settings/domain/entities/notification_preferences_model.dart';

/// The on-device mirror of a user's notification preferences, so the settings
/// screen can paint last-known values instead of a spinner while the Supabase
/// round-trip completes -- `NotificationPreferencesController` is
/// `autoDispose`, so without this every visit starts from an empty state and
/// offline it never populates at all.
///
/// **Keyed per user, deliberately.** A single device-wide key let a second
/// account signing in read the first one's settings. Every identity exit now
/// runs SessionDataWiper, but this stays as defense in depth: the auth
/// listener's signed-out branch (a server-side revocation, an expired refresh
/// token, an account switch) used to clear no preferences. Scoping the key to
/// the user makes the leak impossible regardless of which teardown ran,
/// rather than relying on every path remembering to purge.
///
/// Separate from the controller so the key derivation and the load/save
/// round-trip can be unit-tested with explicit user ids: a `CoupleSession`
/// cannot produce a non-null `userId` without a live Supabase client, so a
/// controller-level test can never reach this logic.
class NotificationPreferencesCache {
  const NotificationPreferencesCache();

  /// Shared by every per-user entry, so [clearAll] can find them all.
  static const String keyPrefix = 'notification_preferences';

  static String keyFor(String userId) => '${keyPrefix}_$userId';

  /// The stored preferences for [userId], or null when nothing is cached or
  /// the entry cannot be parsed. Never throws: a corrupt entry is worth a log
  /// line, not a broken settings screen.
  Future<NotificationPreferences?> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(userId));
      if (raw == null || raw.isEmpty) return null;
      return NotificationPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e, st) {
      debugPrint('NotificationPreferencesCache.load failed: $e\n$st');
      return null;
    }
  }

  Future<void> save(String userId, NotificationPreferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyFor(userId), jsonEncode(preferences.toJson()));
    } catch (e, st) {
      debugPrint('NotificationPreferencesCache.save failed: $e\n$st');
    }
  }

  /// Drops every user's cached preferences on this device.
  ///
  /// Deliberately not scoped to one user: this runs on sign-out, where the
  /// controller has already lost the id it would need to target, and leaving
  /// another account's entry behind serves no purpose.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stale = prefs
          .getKeys()
          .where((k) => k.startsWith(keyPrefix))
          .toList();
      for (final key in stale) {
        await prefs.remove(key);
      }
    } catch (e, st) {
      debugPrint('NotificationPreferencesCache.clearAll failed: $e\n$st');
    }
  }
}
