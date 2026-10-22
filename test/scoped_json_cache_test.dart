// Tests for ScopedJsonCache -- the per-user cache slot shared by the eight
// feature controllers.
//
// The per-user scoping is the point: before it, every controller used a bare
// device-wide key, so an account switch that did not go through logout() left
// the next account reading the previous one's bucket list, calendar, chat
// messages and note-its.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/core/storage/scoped_json_cache.dart';

const cache = ScopedJsonCache('calendar_events');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ScopedJsonCache', () {
    test('round-trips for the signed-in user', () async {
      SharedPreferences.setMockInitialValues({PrefsKeys.userId: 'user-a'});

      await cache.write('["dinner"]');

      expect(await cache.read(), '["dinner"]');
    });

    test('one account cannot read another account\'s cache', () async {
      SharedPreferences.setMockInitialValues({PrefsKeys.userId: 'user-a'});
      await cache.write('["user a data"]');

      // The account switch that skips logout(): a server-side revocation or
      // an expired refresh token clears no preferences, so the previous
      // entry is still on disk when the next account signs in.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.userId, 'user-b');

      expect(
        await cache.read(),
        isNull,
        reason: 'user-b must see nothing, not user-a\'s cached data',
      );

      await prefs.setString(PrefsKeys.userId, 'user-a');
      expect(
        await cache.read(),
        '["user a data"]',
        reason: 'and user-a\'s own entry must be untouched',
      );
    });

    test('keys are distinct per user and share the prefix', () {
      expect(cache.keyFor('user-a'), isNot(cache.keyFor('user-b')));
      expect(cache.keyFor('user-a'), startsWith(cache.keyPrefix));
    });

    test('reads null when no user is signed in', () async {
      expect(await cache.read(), isNull);
    });

    test(
      'writing while signed out is a no-op, not an unscoped write',
      () async {
        await cache.write('["orphan"]');

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getKeys().where((k) => k.startsWith(cache.keyPrefix)),
          isEmpty,
          reason: 'an unscoped write is exactly the leak this class prevents',
        );
      },
    );

    test('clearAll removes every user on the device', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.userId, 'user-a');
      await cache.write('["a"]');
      await prefs.setString(PrefsKeys.userId, 'user-b');
      await cache.write('["b"]');

      await cache.clearAll();

      expect(prefs.getString(cache.keyFor('user-a')), isNull);
      expect(prefs.getString(cache.keyFor('user-b')), isNull);
    });

    test('clearAll leaves other caches and unrelated keys alone', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.userId: 'user-a',
        'your_name': 'Rowel',
      });
      const other = ScopedJsonCache('love_chat_messages');
      await cache.write('["calendar"]');
      await other.write('["chat"]');

      await cache.clearAll();

      expect(await cache.read(), isNull);
      expect(
        await other.read(),
        '["chat"]',
        reason: 'clearAll is scoped to one cache prefix, not a blanket wipe',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('your_name'), 'Rowel');
    });
  });
}
