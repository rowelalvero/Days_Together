/// Every Supabase table the Dart code talks to, in one place.
///
/// Table names were previously raw string literals at ~85 `client.from('...')`
/// call sites across 18 files, plus the ten `tableName` getters that drive
/// realtime subscriptions. A renamed or mistyped table was a runtime failure
/// -- a PostgrestException at the moment a user hit the feature -- rather than
/// a compile error. `PrefsKeys` already proved the pattern for SharedPreferences
/// keys; this is its counterpart for tables, and
/// `test/architecture_test.dart` fails the build on a raw literal at a
/// `.from(` call site so it cannot regress.
///
/// Deliberately lists only the tables Dart actually reads or writes. The
/// rate-limiting and bookkeeping tables (`failed_pairing_attempts`,
/// `pairing_attempt_failures`, `user_recovery_attempts`,
/// `storage_cleanup_queue`) are touched exclusively by SQL functions and
/// triggers, so a constant for them would be dead weight.
///
/// Storage bucket names are not here -- see `StorageBuckets` in
/// `core/storage/storage_url_service.dart`.
class Tables {
  Tables._();

  // Identity and pairing.
  static const String users = 'users';
  static const String couples = 'couples';
  static const String coupleKeyExchanges = 'couple_key_exchanges';
  static const String licenseDetails = 'license_details';

  // Feature data, one per couple-scoped feature.
  static const String timelineItems = 'timeline_items';
  static const String bucketList = 'bucket_list';
  static const String calendarEvents = 'calendar_events';
  static const String giftReminders = 'gift_reminders';
  static const String timeCapsules = 'time_capsules';
  static const String moods = 'moods';
  static const String dailyQuestions = 'daily_questions';
  static const String loveTaps = 'love_taps';
  static const String topicCards = 'topic_cards';
  static const String topicCardLikes = 'topic_card_likes';

  /// Shared by the chat and scrapbook features, discriminated by a `type`
  /// column -- see ADR-005/ADR-013 and `core/models/scrapbook_ref.dart`.
  static const String loveNotes = 'love_notes';

  // Per-user settings and devices (keyed on user_id, not couple_id).
  static const String userNotificationPreferences =
      'user_notification_preferences';
  static const String userFcmTokens = 'user_fcm_tokens';

  /// Every constant above, for the duplicate/coverage checks in
  /// `test/tables_test.dart`.
  static const List<String> all = [
    users,
    couples,
    coupleKeyExchanges,
    licenseDetails,
    timelineItems,
    bucketList,
    calendarEvents,
    giftReminders,
    timeCapsules,
    moods,
    dailyQuestions,
    loveTaps,
    topicCards,
    topicCardLikes,
    loveNotes,
    userNotificationPreferences,
    userFcmTokens,
  ];
}
