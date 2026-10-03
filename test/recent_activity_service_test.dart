// RecentActivityService against a real (in-memory) SQLite -- see
// test/flutter_test_config.dart. Previously its database open failed in
// every test, so none of this was exercised. clearAll() matters beyond
// tidiness: SessionDataWiper relies on it so one account's activity log
// (which quotes bucket items, events, anniversaries) never shows to the next
// account on the device (audit F-06).

import 'package:flutter_test/flutter_test.dart';

import 'package:days_together/core/activity/recent_activity_service.dart';

Future<void> _log(String title) => RecentActivityService.instance.logActivity(
  activityType: 'created',
  title: title,
  description: 'Added: "$title"',
  icon: '📝',
);

void main() {
  final service = RecentActivityService.instance;

  setUp(() => service.clearAll());

  test(
    'logs activities newest-first into the notifier and the database',
    () async {
      await _log('first');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await _log('second');

      expect(service.activitiesNotifier.value.map((a) => a.title), [
        'second',
        'first',
      ]);
      // Reload from the database itself, not the in-memory notifier.
      service.activitiesNotifier.value = [];
      await service.init();
      expect(service.activitiesNotifier.value, hasLength(2));
    },
  );

  test('keeps at most 200 entries, dropping the oldest', () async {
    for (var i = 0; i < 205; i++) {
      await _log('entry $i');
      await Future<void>.delayed(const Duration(microseconds: 50));
    }

    final titles = service.activitiesNotifier.value.map((a) => a.title);
    expect(titles, hasLength(200));
    expect(titles.first, 'entry 204');
    expect(titles, isNot(contains('entry 0')));
  });

  test('clearAll empties both the database and the notifier', () async {
    await _log('private: Paris trip');
    expect(service.activitiesNotifier.value, isNotEmpty);

    await service.clearAll();

    expect(service.activitiesNotifier.value, isEmpty);
    await service.init();
    expect(service.activitiesNotifier.value, isEmpty);
  });
}
