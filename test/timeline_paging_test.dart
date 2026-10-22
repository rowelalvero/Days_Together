// Timeline paging: a paired timeline loads TimelineController.pageSize
// memories at a time instead of the whole table, pages in more as the user
// reaches the end, and keeps whole-timeline figures (counts, first memory)
// correct from server-side stats. The server is faked by overriding
// fetchPage/fetchServerStats with an in-memory table that applies the same
// (date, id) keyset rules as the real query; the real query itself is
// exercised against a live server in test/e2e/realtime_e2e_test.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/core/network/row_change.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/timeline/timeline_state.dart';

const _userId = 'paging-user';
const _coupleId = 'paging-couple';

/// Paired, but never "online": the lifecycle loads the first page directly
/// and opens no realtime subscription.
class _Session extends CoupleSession {
  @override
  String? get userId => _userId;
  @override
  String? get coupleId => _coupleId;
  @override
  bool get isSupabaseAvailable => false;
}

typedef _Call = ({bool ascending, TimelineCursor? after, int limit});

final _base = DateTime.utc(2024, 1, 1);

Map<String, dynamic> _row(int n, {DateTime? date, bool photo = false}) => {
  'id': 'm${n.toString().padLeft(3, '0')}',
  'couple_id': _coupleId,
  'title': 'Memory $n',
  'description': '',
  'date': (date ?? _base.add(Duration(days: n))).toIso8601String(),
  'is_image_card': false,
  'position': 0,
  'mood': '😍',
  'photo_urls': <String>[],
  'is_pinned': false,
  'network_image_url': photo ? 'couples/$_coupleId/timeline/m$n.jpg' : null,
};

int _compare(Map<String, dynamic> a, DateTime date, String id) {
  final byDate = DateTime.parse(a['date'] as String).compareTo(date);
  return byDate != 0 ? byDate : (a['id'] as String).compareTo(id);
}

class _FakeServerTimeline extends TimelineController {
  _FakeServerTimeline(this.table);

  final List<Map<String, dynamic>> table;
  final List<_Call> calls = [];
  bool failPages = false;
  bool failLookups = false;
  int rangeCalls = 0;
  int byIdCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchPage({
    required bool ascending,
    TimelineCursor? after,
    required int limit,
  }) async {
    calls.add((ascending: ascending, after: after, limit: limit));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (failPages) throw Exception('offline');
    final sorted = [...table]
      ..sort((a, b) {
        final c = _compare(
          a,
          DateTime.parse(b['date'] as String),
          b['id'] as String,
        );
        return ascending ? c : -c;
      });
    return sorted
        .where((r) {
          if (after == null) return true;
          final c = _compare(r, after.date, after.id);
          return ascending ? c > 0 : c < 0;
        })
        .take(limit)
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRange({
    required DateTime from,
    required DateTime to,
    TimelineCursor? after,
    required int limit,
  }) async {
    rangeCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (failLookups) throw Exception('offline');
    return table.where((r) {
      final d = DateTime.parse(r['date'] as String);
      return !d.isBefore(from) && d.isBefore(to);
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> fetchById(String id) async {
    byIdCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (failLookups) throw Exception('offline');
    return table.where((r) => r['id'] == id).firstOrNull;
  }

  @override
  Future<TimelineServerStats> fetchServerStats() async {
    final oldest = [...table]
      ..sort(
        (a, b) =>
            _compare(a, DateTime.parse(b['date'] as String), b['id'] as String),
      );
    return (
      total: table.length,
      photos: table.where((r) => r['network_image_url'] != null).length,
      earliest: oldest.isEmpty ? null : oldest.first,
    );
  }
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  late List<Map<String, dynamic>> table;
  late _FakeServerTimeline controller;
  late ProviderContainer container;

  TimelineState state() => container.read(timelineControllerProvider);
  List<String> ids() => state().items.map((i) => i.id).toList();

  Future<void> start({bool ascending = true}) async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.userId: _userId,
      PrefsKeys.timelineIsAscending: ascending,
    });
    container = ProviderContainer(
      overrides: [
        coupleSessionProvider.overrideWithValue(_Session()),
        timelineControllerProvider.overrideWith(() {
          return controller = _FakeServerTimeline(table);
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(timelineControllerProvider, (_, _) {});
    await _settle();
  }

  setUp(() {
    // 25 memories, every 5th one a photo.
    table = [for (var i = 1; i <= 25; i++) _row(i, photo: i % 5 == 0)];
  });

  test('a paired timeline loads only the first page, not the whole '
      'table', () async {
    await start();

    expect(controller.calls, hasLength(1));
    expect(controller.calls.single.limit, TimelineController.pageSize);
    expect(state().items, hasLength(10));
    expect(ids().first, 'm001');
    expect(ids().last, 'm010');
    expect(state().hasMore, isTrue);
  });

  test('whole-timeline figures come from the server, not the window', () async {
    await start(ascending: false);

    expect(state().items, hasLength(10));
    expect(state().memoryCount, 25);
    expect(state().photoMemoryCount, 5);
    // Newest first: the earliest memory is nowhere near this window.
    expect(ids(), isNot(contains('m001')));
    expect(state().firstMemory?.id, 'm001');
  });

  test('scrolling near the end pages in the rest, without gaps or '
      'duplicates, then stops asking', () async {
    await start();

    controller.setCurrentScrubIndex(10 - TimelineController.prefetchThreshold);
    await _settle();
    expect(ids(), [
      for (var i = 1; i <= 20; i++) 'm${i.toString().padLeft(3, '0')}',
    ]);
    expect(state().hasMore, isTrue);

    controller.setCurrentScrubIndex(19);
    await _settle();
    expect(state().items, hasLength(25));
    expect(ids().toSet(), hasLength(25));
    expect(state().hasMore, isFalse);

    final callsBefore = controller.calls.length;
    controller.setCurrentScrubIndex(24);
    await controller.loadMore();
    expect(controller.calls, hasLength(callsBefore));
  });

  test('scrolling far from the end does not fetch', () async {
    await start();
    controller.setCurrentScrubIndex(2);
    await _settle();
    expect(controller.calls, hasLength(1));
    expect(state().items, hasLength(10));
  });

  test('memories sharing a date are neither skipped nor repeated across a '
      'page boundary', () async {
    final sameDay = DateTime.utc(2024, 6, 1, 12);
    table = [for (var i = 1; i <= 15; i++) _row(i, date: sameDay)];
    await start();

    await controller.loadMore();
    expect(state().items, hasLength(15));
    expect(ids().toSet(), hasLength(15));
  });

  test('overlapping loadMore calls fetch once', () async {
    await start();
    await Future.wait([
      controller.loadMore(),
      controller.loadMore(),
      controller.loadMore(),
    ]);
    expect(controller.calls, hasLength(2)); // first page + one more
    expect(state().items, hasLength(20));
  });

  test('flipping the order with more to load starts again from the other '
      'end', () async {
    await start();
    expect(ids().first, 'm001');

    await controller.toggleSortOrder();

    expect(state().isAscending, isFalse);
    expect(controller.calls.last.ascending, isFalse);
    expect(controller.calls.last.after, isNull);
    expect(ids().first, 'm025');
    expect(state().items, hasLength(10));
  });

  test('a new memory arriving live is shown straight away and does not '
      'make the next page skip anything', () async {
    await start();

    final fresh = _row(99, date: DateTime.utc(2030, 1, 1));
    table.add(fresh);
    controller.onRowChange(
      RowChange(type: RowChangeType.insert, newRecord: fresh),
    );
    expect(ids(), contains('m099'));
    expect(ids().last, 'm099'); // oldest-first: newest at the end

    await controller.loadMore();
    for (var i = 1; i <= 20; i++) {
      expect(ids(), contains('m${i.toString().padLeft(3, '0')}'));
    }
    expect(ids().toSet(), hasLength(ids().length));
  });

  test('an update to a memory outside the window is left for its page; a '
      'delete removes a loaded one', () async {
    await start();

    controller.onRowChange(
      RowChange(
        type: RowChangeType.update,
        newRecord: {..._row(20), 'title': 'edited'},
      ),
    );
    expect(ids(), isNot(contains('m020')));

    controller.onRowChange(
      RowChange(type: RowChangeType.delete, oldRecord: {'id': 'm003'}),
    );
    expect(ids(), isNot(contains('m003')));
    expect(ids(), contains('m004'));
    expect(state().items, hasLength(9));
  });

  group('memories outside the page window', () {
    // Long after the first (oldest-first) page, which is January 2024.
    final march2030 = DateTime(2030, 3, 10, 12);

    test('the calendar loads a whole month once, and finds its memories '
        'by day', () async {
      table.add(_row(500, date: march2030.toUtc()));
      await start();
      expect(state().memoriesOn(march2030), isEmpty);

      final results = await Future.wait([
        controller.ensureMonthLoaded(march2030),
        controller.ensureMonthLoaded(march2030),
      ]);
      expect(results, [true, true]);
      expect(controller.rangeCalls, 1);
      expect(state().memoriesOn(march2030).map((i) => i.id), ['m500']);
      // Not spliced into the page window.
      expect(ids(), isNot(contains('m500')));
      expect(state().items, hasLength(10));

      await controller.ensureMonthLoaded(march2030);
      expect(controller.rangeCalls, 1);
    });

    test('a failed month load reports failure and can be retried', () async {
      table.add(_row(500, date: march2030.toUtc()));
      await start();
      controller.failLookups = true;
      expect(await controller.ensureMonthLoaded(march2030), isFalse);
      expect(state().loadedMonths, isEmpty);

      controller.failLookups = false;
      expect(await controller.ensureMonthLoaded(march2030), isTrue);
      expect(state().memoriesOn(march2030), hasLength(1));
    });

    test('a tapped notification loads its memory once; a deleted one comes '
        'back null', () async {
      table.add(_row(500, date: march2030.toUtc()));
      await start();

      final (a, b) = await (
        controller.loadMemory('m500'),
        controller.loadMemory('m500'),
      ).wait;
      expect(a?.title, 'Memory 500');
      expect(b?.id, 'm500');
      expect(controller.byIdCalls, 1);
      expect(state().itemById('m500')?.title, 'Memory 500');

      // Already in the window: no fetch at all.
      expect((await controller.loadMemory('m001'))?.id, 'm001');
      expect(controller.byIdCalls, 1);

      expect(await controller.loadMemory('gone'), isNull);
    });

    test(
      'a failed memory fetch throws so the screen can offer a retry',
      () async {
        await start();
        controller.failLookups = true;
        await expectLater(controller.loadMemory('m020'), throwsException);
        controller.failLookups = false;
        expect((await controller.loadMemory('m020'))?.id, 'm020');
      },
    );

    test('live edits and deletes reach a memory held outside the '
        'window', () async {
      table.add(_row(500, date: march2030.toUtc()));
      await start();
      await controller.loadMemory('m500');

      controller.onRowChange(
        RowChange(
          type: RowChangeType.update,
          newRecord: {
            ..._row(500, date: march2030.toUtc()),
            'title': 'edited',
          },
        ),
      );
      expect(state().itemById('m500')?.title, 'edited');
      expect(ids(), isNot(contains('m500')));

      controller.onRowChange(
        RowChange(type: RowChangeType.delete, oldRecord: {'id': 'm500'}),
      );
      expect(state().itemById('m500'), isNull);
      expect(state().itemById('m001'), isNotNull);
    });
  });

  group('loading, error and end-of-list states', () {
    test('a failed page pauses automatic loading until retried', () async {
      await start();
      controller.failPages = true;

      await controller.loadMore();
      expect(state().paging.loadMoreFailed, isTrue);
      expect(state().paging.isLoadingMore, isFalse);
      expect(state().items, hasLength(10));

      // Scrolling to the end again does not hammer the failing network.
      final callsAfterFailure = controller.calls.length;
      controller.setCurrentScrubIndex(9);
      await _settle();
      expect(controller.calls, hasLength(callsAfterFailure));

      controller.failPages = false;
      await controller.retryLoad();
      expect(state().paging.loadMoreFailed, isFalse);
      expect(state().items, hasLength(20));
    });

    test('a failed first page shows as an error and the retry loads '
        'it', () async {
      SharedPreferences.setMockInitialValues({PrefsKeys.userId: _userId});
      container = ProviderContainer(
        overrides: [
          coupleSessionProvider.overrideWithValue(_Session()),
          timelineControllerProvider.overrideWith(
            () => controller = _FakeServerTimeline(table)..failPages = true,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(timelineControllerProvider, (_, _) {});
      await _settle();

      expect(state().items, isEmpty);
      expect(state().paging.loadMoreFailed, isTrue);
      expect(state().isLoading, isFalse);

      controller.failPages = false;
      await controller.retryLoad();
      expect(state().items, hasLength(10));
      expect(state().paging.loadMoreFailed, isFalse);
      expect(state().paging.hasMore, isTrue);
    });

    test('the end of the list is reported once everything is in', () async {
      table = [for (var i = 1; i <= 7; i++) _row(i)];
      await start();
      expect(state().items, hasLength(7));
      expect(state().paging.hasMore, isFalse);
      expect(state().paging.isExhausted, isTrue);
    });
  });
}
