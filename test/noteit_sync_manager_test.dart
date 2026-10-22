// Tests for NoteitSyncManager's queue lifecycle. No network: the manager is
// a private NoteitSyncManager.forTest() instance whose connectivity is
// stubbed offline, so triggerSync() never reaches Supabase, and the host is
// a plain fake rather than a NoteitController.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/scrapbook/data/noteit_sync_manager.dart';
import 'package:days_together/shared/models/noteit_model.dart';

const String _queueKey = 'noteit_sync_queue';

class _FakeHost implements NoteitSyncHost {
  _FakeHost(this.coupleId);

  @override
  String? coupleId;
  @override
  String? sessionUserId = 'u1';
  final List<(String, SyncStatus)> statuses = [];

  @override
  void updateItemSyncStatus(String id, SyncStatus status) =>
      statuses.add((id, status));
}

NoteitSyncTask _task(String id, {String status = 'pending'}) => NoteitSyncTask(
  id: id,
  type: NoteitType.text,
  content: 'note $id',
  createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: id.hashCode % 60)),
  status: status,
);

String _persisted(List<NoteitSyncTask> tasks) =>
    jsonEncode(tasks.map((t) => t.toJson()).toList());

Future<List<String>> _persistedIds() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_queueKey);
  if (raw == null) return [];
  return (jsonDecode(raw) as List).map((j) => j['id'] as String).toList();
}

void main() {
  late NoteitSyncManager manager;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    manager = NoteitSyncManager.forTest();
  });

  tearDown(() => manager.reset());

  test('initialize loads the persisted queue', () async {
    SharedPreferences.setMockInitialValues({
      _queueKey: _persisted([_task('a'), _task('b')]),
    });

    await manager.initialize(_FakeHost('c1'));

    expect(manager.queue.map((t) => t.id), unorderedEquals(['a', 'b']));
  });

  test(
    'a task persisted as syncing (app died mid-upload) loads as pending',
    () async {
      SharedPreferences.setMockInitialValues({
        _queueKey: _persisted([
          _task('stuck', status: 'syncing'),
          _task('failed', status: 'failed'),
        ]),
      });

      await manager.initialize(_FakeHost('c1'));

      final byId = {for (final t in manager.queue) t.id: t.status};
      expect(byId['stuck'], 'pending');
      // Only 'syncing' is rewritten; a genuine failure stays failed.
      expect(byId['failed'], 'failed');
    },
  );

  group('pending notes never cross into another relationship', () {
    test('a couple change drops the in-memory queue once the persisted '
        'copy has been wiped', () async {
      SharedPreferences.setMockInitialValues({
        _queueKey: _persisted([_task('old')]),
      });
      final host = _FakeHost('c1');
      await manager.initialize(host);
      expect(manager.queue.map((t) => t.id), ['old']);

      // Unlink: SessionDataWiper removes the persisted queue...
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      // ...and the same controller is then paired into a new couple.
      host.coupleId = 'c2';
      await manager.initialize(host);

      expect(manager.queue, isEmpty);
      // A later enqueue must not write the old couple's note back to disk.
      await manager.enqueue(_task('new'));
      expect(await _persistedIds(), ['new']);
    });

    test(
      'reset clears the queue and stops a later save resurrecting it',
      () async {
        final host = _FakeHost('c1');
        await manager.initialize(host);
        await manager.enqueue(_task('old'));
        expect(await _persistedIds(), ['old']);

        manager.reset();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_queueKey);

        expect(manager.queue, isEmpty);
        await manager.initialize(_FakeHost('c2'));
        await manager.enqueue(_task('new'));
        expect(manager.queue.map((t) => t.id), ['new']);
        expect(await _persistedIds(), ['new']);
      },
    );
  });

  group('re-initializing on unrelated session changes', () {
    test('is a no-op for the same host and couple', () async {
      final host = _FakeHost('c1');
      await manager.initialize(host);
      await manager.enqueue(_task('a'));

      // Something else rewrites the persisted queue; a reload would
      // replace the in-memory queue with it.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_queueKey, _persisted([_task('other')]));
      await manager.initialize(host);

      expect(manager.queue.map((t) => t.id), ['a']);
    });

    test('an enqueue racing the initial load is not lost', () async {
      SharedPreferences.setMockInitialValues({
        _queueKey: _persisted([_task('seeded')]),
      });
      final host = _FakeHost('c1');

      // Deliberately not awaited: the session bridge doesn't await it either.
      final loading = manager.initialize(host);
      final enqueuing = manager.enqueue(_task('fresh'));
      await Future.wait([loading, enqueuing]);

      expect(
        manager.queue.map((t) => t.id),
        unorderedEquals(['seeded', 'fresh']),
      );
      expect(await _persistedIds(), unorderedEquals(['seeded', 'fresh']));
      expect(host.statuses, contains(('fresh', SyncStatus.sending)));
    });
  });
}
