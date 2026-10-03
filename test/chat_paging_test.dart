// Chat history paging: a paired chat loads the newest
// LoveChatController.maxLocalMessages messages, then older history
// olderPageSize at a time as the user scrolls up (loadOlder). The server is
// faked by overriding fetchPage with an in-memory table applying the same
// (created_at, id) keyset as the real query; the real query runs against a
// live server in test/e2e/realtime_e2e_test.dart.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/core/network/row_change.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/core/storage/scoped_json_cache.dart';
import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/features/chat/love_chat_state.dart';

const _userId = 'chat-paging-user';
const _coupleId = 'chat-paging-couple';

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
  'id': 'c${n.toString().padLeft(4, '0')}',
  'couple_id': _coupleId,
  'type': 'chat',
  'content': 'message $n',
  'sender_id': n.isEven ? _userId : 'partner',
  'created_at': (at ?? _base.add(Duration(minutes: n))).toIso8601String(),
};

int _compare(Map<String, dynamic> r, DateTime at, String id) {
  final byDate = DateTime.parse(r['created_at'] as String).compareTo(at);
  return byDate != 0 ? byDate : (r['id'] as String).compareTo(id);
}

class _FakeServerChat extends LoveChatController {
  _FakeServerChat(this.table);

  final List<Map<String, dynamic>> table;
  final List<ChatCursor?> calls = [];
  bool fail = false;

  @override
  Future<List<Map<String, dynamic>>> fetchPage({
    ChatCursor? before,
    required int limit,
  }) async {
    calls.add(before);
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
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  late List<Map<String, dynamic>> table;
  late _FakeServerChat controller;
  late ProviderContainer container;

  LoveChatState state() => container.read(loveChatControllerProvider);
  List<String> ids() => state().messages.map((m) => m.id).toList();

  Future<void> start({bool fail = false}) async {
    SharedPreferences.setMockInitialValues({PrefsKeys.userId: _userId});
    container = ProviderContainer(
      overrides: [
        coupleSessionProvider.overrideWithValue(_Session()),
        loveChatControllerProvider.overrideWith(
          () => controller = _FakeServerChat(table)..fail = fail,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(loveChatControllerProvider, (_, _) {});
    await _settle();
  }

  setUp(() {
    table = [for (var i = 1; i <= 230; i++) _row(i)];
  });

  test('opens on the newest page, newest first', () async {
    await start();
    expect(controller.calls, [null]);
    expect(state().messages, hasLength(LoveChatController.maxLocalMessages));
    expect(ids().first, 'c0230');
    expect(ids().last, 'c0131');
    expect(state().paging.hasMore, isTrue);
  });

  test('scrolling up pages in all older history exactly once, then '
      'stops', () async {
    await start();

    await controller.loadOlder();
    expect(state().messages, hasLength(150));
    expect(ids().last, 'c0081');

    await controller.loadOlder();
    await controller.loadOlder(); // 30 left: a short page
    expect(state().messages, hasLength(230));
    expect(ids().toSet(), hasLength(230));
    expect(ids().last, 'c0001');
    expect(state().paging.hasMore, isFalse);

    final calls = controller.calls.length;
    await controller.loadOlder();
    expect(controller.calls, hasLength(calls));
  });

  test('overlapping loadOlder calls fetch once', () async {
    await start();
    await Future.wait([controller.loadOlder(), controller.loadOlder()]);
    expect(controller.calls, hasLength(2)); // newest page + one older
  });

  test('messages sharing a timestamp across a page boundary are neither '
      'skipped nor repeated', () async {
    final same = DateTime.utc(2025, 6, 1);
    table = [for (var i = 1; i <= 130; i++) _row(i, at: same)];
    await start();
    await controller.loadOlder();
    expect(state().messages, hasLength(130));
    expect(ids().toSet(), hasLength(130));
  });

  test('a live message does not disturb older paging, and older pages '
      'are not trimmed away', () async {
    await start();
    final fresh = _row(999, at: DateTime.utc(2030));
    table.add(fresh);
    controller.onRowChange(
      RowChange(type: RowChangeType.insert, newRecord: fresh),
    );
    expect(ids().first, 'c0999');

    await controller.loadOlder();
    expect(state().messages, hasLength(151));
    expect(ids(), contains('c0081'));
    expect(ids().toSet(), hasLength(151));
  });

  test('the on-disk cache stays bounded however much history is '
      'loaded', () async {
    await start();
    await controller.loadOlder();
    await controller.loadOlder();
    controller.onRowChange(
      RowChange(type: RowChangeType.insert, newRecord: _row(500)),
    );
    await _settle();
    final prefs = await SharedPreferences.getInstance();
    final cached =
        jsonDecode(
              prefs.getString(
                const ScopedJsonCache('love_chat_messages').keyFor(_userId),
              )!,
            )
            as List;
    expect(cached, hasLength(LoveChatController.maxLocalMessages));
    expect(state().messages.length, greaterThan(cached.length));
  });

  test('a failed older page shows as an error until retried', () async {
    await start();
    controller.fail = true;
    await controller.loadOlder();
    expect(state().paging.loadMoreFailed, isTrue);
    expect(state().paging.isLoadingMore, isFalse);
    expect(state().paging.canAutoLoad, isFalse);

    controller.fail = false;
    await controller.retryLoad();
    expect(state().paging.loadMoreFailed, isFalse);
    expect(state().messages, hasLength(150));
  });

  test('a failed first page is retried from the top', () async {
    await start(fail: true);
    expect(state().paging.loadMoreFailed, isTrue);
    // The welcome message from the empty cache, not the server.
    expect(ids(), isNot(contains('c0230')));

    controller.fail = false;
    await controller.retryLoad();
    expect(ids().first, 'c0230');
    expect(state().messages, hasLength(LoveChatController.maxLocalMessages));
  });
}
