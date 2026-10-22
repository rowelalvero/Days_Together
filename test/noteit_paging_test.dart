// Scrapbook (note-it) paging: a paired scrapbook loads the newest
// NoteitController.pageSize notes, then older ones as the history grid
// scrolls, so the doodles' stroke payloads aren't all downloaded up front.
// Notes referenced from elsewhere (an old chat message) load by id; Wrapped
// loads a year. The server is faked in memory; the real queries run against
// a live server in test/e2e/realtime_e2e_test.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/core/network/row_change.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/features/scrapbook/noteit_state.dart';

const _userId = 'noteit-paging-user';
const _coupleId = 'noteit-paging-couple';

class _Session extends CoupleSession {
  @override
  String? get userId => _userId;
  @override
  String? get coupleId => _coupleId;
  @override
  bool get isSupabaseAvailable => false;
}

final _base = DateTime.utc(2025, 1, 1);

Map<String, dynamic> _row(int n, {DateTime? at}) => {
  'id': 'n${n.toString().padLeft(3, '0')}',
  'couple_id': _coupleId,
  'type': 'text',
  'content': 'note $n',
  'sender_id': n.isEven ? _userId : 'partner',
  'created_at': (at ?? _base.add(Duration(days: n))).toIso8601String(),
};

int _compare(Map<String, dynamic> r, DateTime at, String id) {
  final byDate = DateTime.parse(r['created_at'] as String).compareTo(at);
  return byDate != 0 ? byDate : (r['id'] as String).compareTo(id);
}

class _FakeServerNotes extends NoteitController {
  _FakeServerNotes(this.table);

  final List<Map<String, dynamic>> table;
  int pageCalls = 0;
  final List<List<String>> idCalls = [];
  bool fail = false;

  @override
  Future<List<Map<String, dynamic>>> fetchPage({
    NoteitCursor? before,
    required int limit,
  }) async {
    pageCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (fail) throw Exception('offline');
    final newestFirst = [...table]
      ..sort(
        (a, b) => -_compare(
          a,
          DateTime.parse(b['created_at'] as String),
          b['id'] as String,
        ),
      );
    return newestFirst
        .where(
          (r) => before == null || _compare(r, before.createdAt, before.id) < 0,
        )
        .take(limit)
        .toList();
  }

  @override
  Future<int> fetchCount() async => table.length;

  @override
  Future<List<Map<String, dynamic>>> fetchByIds(List<String> ids) async {
    idCalls.add(ids);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return table.where((r) => ids.contains(r['id'])).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRange(
    DateTime from,
    DateTime to,
  ) async {
    return table.where((r) {
      final d = DateTime.parse(r['created_at'] as String);
      return !d.isBefore(from) && d.isBefore(to);
    }).toList();
  }
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  late List<Map<String, dynamic>> table;
  late _FakeServerNotes controller;
  late ProviderContainer container;

  NoteitState state() => container.read(noteitControllerProvider);
  List<String> ids() => state().visibleNotes.map((n) => n.id).toList();

  Future<void> start() async {
    SharedPreferences.setMockInitialValues({PrefsKeys.userId: _userId});
    container = ProviderContainer(
      overrides: [
        coupleSessionProvider.overrideWithValue(_Session()),
        noteitControllerProvider.overrideWith(
          () => controller = _FakeServerNotes(table),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(noteitControllerProvider, (_, _) {});
    await _settle();
  }

  setUp(() {
    table = [for (var i = 1; i <= 45; i++) _row(i)];
  });

  test('loads the newest page only, and counts the whole scrapbook', () async {
    await start();
    expect(controller.pageCalls, 1);
    expect(state().visibleNotes, hasLength(NoteitController.pageSize));
    expect(ids().first, 'n045');
    expect(state().noteCount, 45);
    expect(state().paging.hasMore, isTrue);
  });

  test('loadMore pages in every older note exactly once, then stops', () async {
    await start();
    await controller.loadMore();
    await controller.loadMore();
    expect(state().visibleNotes, hasLength(45));
    expect(ids().toSet(), hasLength(45));
    expect(ids().last, 'n001');
    expect(state().paging.hasMore, isFalse);

    await controller.loadMore();
    expect(controller.pageCalls, 3);
  });

  test('notes an old chat message refers to load by id, once', () async {
    await start();
    expect(state().noteById('n003'), isNull);

    await Future.wait([
      controller.ensureLoaded(['n003', 'n045']), // n045 is already loaded
      controller.ensureLoaded(['n003']),
    ]);
    expect(controller.idCalls, [
      ['n003'],
    ]);
    expect(state().noteById('n003')?.content, 'note 3');
    expect(state().knownNotes.map((n) => n.id), contains('n003'));
    // Kept out of the page window (and so out of the history grid order).
    expect(ids(), isNot(contains('n003')));
  });

  test('Wrapped loads a whole year of notes', () async {
    table.add(_row(900, at: DateTime.utc(2023, 5, 5)));
    await start();
    expect(
      await controller.ensureRangeLoaded(DateTime(2023), DateTime(2024)),
      isTrue,
    );
    expect(
      state().knownNotes
          .where((n) => n.createdAt.year == 2023)
          .map((n) => n.id),
      ['n900'],
    );
  });

  test('a deleted note leaves both the window and the detached set', () async {
    await start();
    await controller.ensureLoaded(['n003']);
    controller.onRowChange(
      const RowChange(type: RowChangeType.delete, oldRecord: {'id': 'n003'}),
    );
    controller.onRowChange(
      const RowChange(type: RowChangeType.delete, oldRecord: {'id': 'n045'}),
    );
    expect(state().noteById('n003'), isNull);
    expect(state().noteById('n045'), isNull);
    expect(state().noteById('n044'), isNotNull);
  });

  test('a failed page shows as an error until retried', () async {
    await start();
    controller.fail = true;
    await controller.loadMore();
    expect(state().paging.loadMoreFailed, isTrue);
    expect(state().paging.canAutoLoad, isFalse);

    controller.fail = false;
    await controller.retryLoad();
    expect(state().paging.loadMoreFailed, isFalse);
    expect(state().visibleNotes, hasLength(40));
  });
}
