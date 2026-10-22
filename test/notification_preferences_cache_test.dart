// Tests for NotificationPreferencesCache -- the per-user on-device mirror of
// a user's notification settings.
//
// These live apart from notification_preferences_controller_test.dart on
// purpose: CoupleSession cannot produce a non-null userId without a live
// Supabase client, so a controller-level test can never reach the cache's
// real code path. Testing the cache directly is the only way to pin the
// per-user scoping that stops one account reading another's settings.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/settings/data/notification_preferences_cache.dart';
import 'package:days_together/features/settings/domain/entities/notification_preferences_model.dart';

const cache = NotificationPreferencesCache();

NotificationPreferences _prefsFor(String userId, {required bool muteAll}) =>
    NotificationPreferences(
      userId: userId,
      timezone: 'UTC',
    ).copyWith(muteAll: muteAll);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationPreferencesCache', () {
    test('round-trips a saved entry for the same user', () async {
      await cache.save('user-a', _prefsFor('user-a', muteAll: true));

      final loaded = await cache.load('user-a');

      expect(loaded, isNotNull);
      expect(loaded!.userId, 'user-a');
      expect(loaded.muteAll, isTrue);
    });

    test('one account cannot read another account\'s settings', () async {
      // The whole point of the per-user key. A single device-wide key let a
      // second account signing in on the same device inherit the first one's
      // settings -- and an early toggle then upserted against the previous
      // user's row.
      await cache.save('user-a', _prefsFor('user-a', muteAll: true));

      expect(
        await cache.load('user-b'),
        isNull,
        reason: 'user-b must see nothing, not user-a\'s cached preferences',
      );
      expect(
        await cache.load('user-a'),
        isNotNull,
        reason: 'and user-a\'s own entry must be untouched',
      );
    });

    test('keys are distinct per user', () {
      expect(
        NotificationPreferencesCache.keyFor('user-a'),
        isNot(NotificationPreferencesCache.keyFor('user-b')),
      );
      expect(
        NotificationPreferencesCache.keyFor('user-a'),
        startsWith(NotificationPreferencesCache.keyPrefix),
        reason: 'clearAll finds entries by this prefix',
      );
    });

    test('returns null when nothing is cached', () async {
      expect(await cache.load('nobody'), isNull);
    });

    test('a corrupt entry returns null rather than throwing', () async {
      SharedPreferences.setMockInitialValues({
        NotificationPreferencesCache.keyFor('user-a'): 'not json',
      });

      expect(await cache.load('user-a'), isNull);
    });

    test('clearAll removes every user on the device', () async {
      // Sign-out reaches here with the user id already gone, so it cannot
      // target one entry -- and leaving another account's behind serves no
      // purpose.
      await cache.save('user-a', _prefsFor('user-a', muteAll: true));
      await cache.save('user-b', _prefsFor('user-b', muteAll: false));

      await cache.clearAll();

      expect(await cache.load('user-a'), isNull);
      expect(await cache.load('user-b'), isNull);
    });

    test('clearAll leaves unrelated SharedPreferences keys alone', () async {
      SharedPreferences.setMockInitialValues({
        'your_name': 'Rowel',
        NotificationPreferencesCache.keyFor('user-a'): jsonEncode(
          _prefsFor('user-a', muteAll: true).toJson(),
        ),
      });

      await cache.clearAll();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('your_name'),
        'Rowel',
        reason: 'clearAll is scoped by prefix, not a blanket wipe',
      );
      expect(await cache.load('user-a'), isNull);
    });
  });
}
