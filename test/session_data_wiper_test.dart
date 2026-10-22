// SessionDataWiper scope rules (audit F-06 / invariant S11).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/core/session/session_data_wiper.dart';

const _seed = <String, Object>{
  // device
  PrefsKeys.appSettings: '{"theme":"rose"}',
  PrefsKeys.timelineIsAscending: false,
  // user
  PrefsKeys.userId: 'user-a',
  PrefsKeys.yourName: 'Alice',
  PrefsKeys.yourPhone: '555-0001',
  'notification_preferences_user-a': '{}',
  // couple
  PrefsKeys.coupleId: 'couple-a',
  PrefsKeys.partnerName: 'Pat',
  PrefsKeys.partnerPhone: '555-0100',
  PrefsKeys.partnerSignature: 'sig',
  PrefsKeys.relationshipStartDate: '2020-02-14',
  'love_chat_messages_user-a': '[]',
  'timeline_items_user-a': '[]',
  'topic_cards_custom': '[]',
  'wrapped_archive_2025': '{}',
  'noteit_sync_queue': '[]',
  // a key nobody has classified yet
  'some_future_key': 'x',
};

void main() {
  late List<String> derived;
  late SessionDataWiper wiper;

  setUp(() {
    SharedPreferences.setMockInitialValues(Map.of(_seed));
    derived = [];
    wiper = SessionDataWiper(
      clearActivityLog: () async => derived.add('activity'),
      clearImageCaches: () async => derived.add('images'),
      clearSignedUrls: () => derived.add('urls'),
    );
  });

  test('wipeAccountData keeps only device-scoped keys', () async {
    await wiper.wipeAccountData();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {
      PrefsKeys.appSettings,
      PrefsKeys.timelineIsAscending,
    });
    expect(prefs.getString(PrefsKeys.appSettings), '{"theme":"rose"}');
    expect(derived, ['activity', 'images', 'urls']);
  });

  test('an unclassified new key is wiped by default (allowlist)', () async {
    await wiper.wipeAccountData();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('some_future_key'), isFalse);
  });

  test('wipeCoupleData removes the couple scope and keeps the user', () async {
    await wiper.wipeCoupleData();
    final prefs = await SharedPreferences.getInstance();
    for (final gone in [
      PrefsKeys.coupleId,
      PrefsKeys.partnerName,
      PrefsKeys.partnerPhone,
      PrefsKeys.partnerSignature,
      PrefsKeys.relationshipStartDate,
      'love_chat_messages_user-a',
      'timeline_items_user-a',
      'topic_cards_custom',
      'wrapped_archive_2025',
      'noteit_sync_queue',
    ]) {
      expect(prefs.containsKey(gone), isFalse, reason: gone);
    }
    expect(prefs.getString(PrefsKeys.userId), 'user-a');
    expect(prefs.getString(PrefsKeys.yourName), 'Alice');
    expect(prefs.getString(PrefsKeys.yourPhone), '555-0001');
    expect(prefs.getString('notification_preferences_user-a'), '{}');
    expect(prefs.getString(PrefsKeys.appSettings), '{"theme":"rose"}');
    expect(derived, ['activity', 'images', 'urls']);
  });

  test('a failing derived-store step does not strand the others', () async {
    final calls = <String>[];
    final fragile = SessionDataWiper(
      clearActivityLog: () async => throw StateError('no sqlite'),
      clearImageCaches: () async => calls.add('images'),
      clearSignedUrls: () => calls.add('urls'),
    );
    await fragile.wipeAccountData();
    expect(calls, ['images', 'urls']);
  });

  test('every partner* PrefsKey is couple-scoped', () {
    final partnerKeys = PrefsKeys.all.where((k) => k.startsWith('partner_'));
    expect(partnerKeys, isNotEmpty);
    expect(
      partnerKeys.where((k) => !SessionDataWiper.coupleScopedKeys.contains(k)),
      isEmpty,
    );
  });

  test(
    'every ScopedJsonCache feature cache under lib/ is covered by a couple prefix',
    () {
      // core cannot import features, so the wiper lists feature cache
      // prefixes itself; this keeps that list from drifting when a feature
      // adds a cache.
      final declared = <String>{};
      final pattern = RegExp(r"ScopedJsonCache\(\s*'([a-z_]+)'");
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        for (final m in pattern.allMatches(file.readAsStringSync())) {
          declared.add(m.group(1)!);
        }
      }
      expect(declared.length, greaterThanOrEqualTo(8));
      final uncovered = declared.where(
        (p) => !SessionDataWiper.coupleScopedPrefixes.any(p.startsWith),
      );
      expect(uncovered, isEmpty);
    },
  );
}
