import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/activity/recent_activity_service.dart';
import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/core/storage/storage_url_service.dart';
import 'package:days_together/shared/widgets/storage_image.dart'
    show clearStorageImageCaches;

/// The one place that decides which on-device data survives which identity
/// transition (audit F-06 / invariant S11).
///
/// Local data falls into three scopes:
///
/// * **Device** -- [deviceScopedKeys]: device chrome (theme/music, the
///   timeline sort order). Survives everything.
/// * **User** -- the signed-in account's own profile mirror, license fields,
///   notification-preference cache. Survives an unlink, never an identity
///   change. The E2EE keys in secure storage are also user-scoped, but they
///   are keyed by user id and are deliberately NOT touched here: a returning
///   user needs them to read their photos (see KeyManagementService).
/// * **Couple** -- pairing state, relationship dates, partner PII, every
///   feature cache, the recent-activity log, decrypted images, signed URLs.
///   Gone the moment the relationship ends.
///
/// [wipeAccountData] runs on every identity exit: explicit logout, the auth
/// session going null (revocation, expiry), account deletion, and a
/// different account signing in on a device that still holds another's data.
/// It keeps ONLY the device scope -- an allowlist, so a key added later is
/// wiped by default rather than leaked by default.
///
/// [wipeCoupleData] runs on unlink and removes the couple scope only.
///
/// Callers must not add their own `prefs.remove(...)` for account data;
/// extend the scope lists here instead.
class SessionDataWiper {
  SessionDataWiper({
    Future<void> Function()? clearActivityLog,
    Future<void> Function()? clearImageCaches,
    void Function()? clearSignedUrls,
  }) : _clearActivityLog =
           clearActivityLog ?? RecentActivityService.instance.clearAll,
       _clearImageCaches = clearImageCaches ?? clearStorageImageCaches,
       _clearSignedUrls =
           clearSignedUrls ?? StorageUrlService.instance.clearAll;

  final Future<void> Function() _clearActivityLog;
  final Future<void> Function() _clearImageCaches;
  final void Function() _clearSignedUrls;

  /// Survives every identity transition.
  static const Set<String> deviceScopedKeys = {
    PrefsKeys.appSettings,
    PrefsKeys.timelineIsAscending,
  };

  /// Exact SharedPreferences keys that belong to the relationship.
  static const Set<String> coupleScopedKeys = {
    PrefsKeys.coupleId,
    PrefsKeys.partnerId,
    PrefsKeys.isPaired,
    PrefsKeys.isCreator,
    PrefsKeys.coupleCode,
    PrefsKeys.isPremium,
    PrefsKeys.storyTitle,
    PrefsKeys.relationshipStartDate,
    PrefsKeys.relationshipStartHour,
    PrefsKeys.relationshipStartMinute,
    PrefsKeys.partnerName,
    PrefsKeys.partnerAvatarPath,
    PrefsKeys.partnerJoinDate,
    PrefsKeys.partnerGender,
    PrefsKeys.partnerPhone,
    PrefsKeys.partnerBirthdate,
    PrefsKeys.partnerAddress,
    PrefsKeys.partnerNationality,
    PrefsKeys.partnerWeight,
    PrefsKeys.partnerHeight,
    PrefsKeys.partnerBloodType,
    PrefsKeys.partnerEyeColor,
    PrefsKeys.partnerConditions,
    PrefsKeys.partnerDateIssued,
    PrefsKeys.partnerSignature,
  };

  /// Key prefixes of couple-scoped stores owned by features (core cannot
  /// import them, so they are listed here; test/session_data_wiper_test.dart
  /// fails if a ScopedJsonCache prefix declared under lib/ is missing).
  static const List<String> coupleScopedPrefixes = [
    // ScopedJsonCache feature caches (`<prefix>_<userId>`).
    'bucket_list_items',
    'calendar_events',
    'love_chat_messages',
    'gift_reminders',
    'time_capsules',
    'daily_moods',
    'partner_daily_moods',
    'daily_sync_questions',
    'love_notes_items',
    'timeline_items',
    // Topic-card deck/likes, Wrapped archives, note-it draft + sync queue.
    'topic_cards_',
    'wrapped_archive_',
    'noteit_',
  ];

  /// Removes everything except [deviceScopedKeys]. See the class doc.
  Future<void> wipeAccountData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (!deviceScopedKeys.contains(key)) await prefs.remove(key);
    }
    await _clearDerivedCoupleData();
  }

  /// Removes the couple scope, keeping the user's own data. See the class
  /// doc.
  Future<void> wipeCoupleData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (coupleScopedKeys.contains(key) ||
          coupleScopedPrefixes.any(key.startsWith)) {
        await prefs.remove(key);
      }
    }
    await _clearDerivedCoupleData();
  }

  /// Non-prefs couple data: each step is independent and best-effort, so one
  /// failing (e.g. the sqlite factory missing) never strands the others.
  Future<void> _clearDerivedCoupleData() async {
    try {
      await _clearActivityLog();
    } catch (e) {
      debugPrint('SessionDataWiper: clearing the activity log failed: $e');
    }
    try {
      await _clearImageCaches();
    } catch (e) {
      debugPrint('SessionDataWiper: clearing image caches failed: $e');
    }
    try {
      _clearSignedUrls();
    } catch (e) {
      debugPrint('SessionDataWiper: clearing signed URLs failed: $e');
    }
  }
}
