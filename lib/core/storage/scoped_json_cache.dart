import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/constants/prefs_keys.dart';

/// A per-user slot in `SharedPreferences` for one feature's offline cache.
///
/// Eight feature controllers each hand-rolled the same three operations --
/// read a JSON string, write a JSON string, drop the key -- around the same
/// try/catch-and-log. This owns that, plus the one thing they all got wrong.
///
/// **Keyed per user.** Every cache key used to be a bare device-wide constant
/// (`'calendar_events'`, `'love_chat_messages'`, ...). Every identity exit now
/// runs SessionDataWiper (logout, the auth listener's signed-out branch, an
/// account switch), but this stays as defense in depth: before that, the
/// signed-out branch (a server-side revocation, an expired refresh token)
/// cleared nothing, and a second account signing in on that device would then
/// load the previous account's cached bucket list, calendar, chat messages and
/// note-its until the network sync replaced them. Scoping the key to the user
/// makes that impossible regardless of which teardown path ran, instead of
/// relying on every path remembering to purge.
///
/// **Reads its own scope from `SharedPreferences`, not from `CoupleSession`.**
/// A controller calls this from `build()`, and `CoupleSession._loadLocalData`
/// is asynchronous, so `session.userId` can still be null at that moment even
/// though an id is on disk. Reading [PrefsKeys.userId] directly makes the
/// cache independent of session timing -- it is a preferences-level concern
/// resolving a preferences-level value. The mirror is cleared on sign-out, so
/// it never outlives the session it belongs to.
///
/// Scoped on **user**, not couple, because two features cache before a couple
/// exists: love chat seeds a welcome message and note-it keeps local drafts
/// while still unpaired. A couple-scoped key would silently stop persisting
/// for them.
///
/// Deliberately not generic over the payload. The eight callers decode into
/// lists, sets, maps and single objects, several with a sort -- absorbing that
/// would mean a type parameter and three overloads to save one line each. This
/// owns the part that was genuinely identical: the key, the
/// `SharedPreferences` handle, and not throwing.
class ScopedJsonCache {
  const ScopedJsonCache(this.keyPrefix);

  /// Shared by every per-user entry of this cache so [clearAll] can find them.
  /// Matches the old unscoped key name, which keeps a `SharedPreferences` dump
  /// readable.
  final String keyPrefix;

  String keyFor(String userId) => '${keyPrefix}_$userId';

  Future<String?> _currentUserId(SharedPreferences prefs) =>
      Future.value(prefs.getString(PrefsKeys.userId));

  /// The stored JSON for the signed-in user, or null when nothing is cached,
  /// the read fails, or no user id is on disk yet.
  ///
  /// A missing user id is not an error -- it is simply a device with no
  /// signed-in account, which has no per-user slot to read.
  Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await _currentUserId(prefs);
      if (userId == null) return null;
      return prefs.getString(keyFor(userId));
    } catch (e, st) {
      debugPrint('ScopedJsonCache($keyPrefix).read failed: $e\n$st');
      return null;
    }
  }

  /// Stores [json] for the signed-in user. A no-op when signed out: there is
  /// no account to attribute the data to, and writing it unscoped is the leak
  /// this class exists to prevent.
  Future<void> write(String json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await _currentUserId(prefs);
      if (userId == null) return;
      await prefs.setString(keyFor(userId), json);
    } catch (e, st) {
      debugPrint('ScopedJsonCache($keyPrefix).write failed: $e\n$st');
    }
  }

  /// Drops every user's entry for this cache on this device.
  ///
  /// Deliberately not scoped to one user: `purgeCache()` runs on sign-out,
  /// where the id may already be gone, and leaving another account's entry
  /// behind serves no purpose.
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
      debugPrint('ScopedJsonCache($keyPrefix).clearAll failed: $e\n$st');
    }
  }
}
