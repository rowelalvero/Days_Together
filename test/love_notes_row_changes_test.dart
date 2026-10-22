// Row-level realtime for love_notes (audit F-18). Chat and note-its used to
// receive the WHOLE love_notes table from `.stream()` on every launch,
// reconnect and change; they now keep a bounded REST snapshot and apply
// individual changes. These tests pin that the changes produce exactly the
// state the full-list handlers used to: right rows, no duplicates, chat and
// note-its kept apart, deletes by id alone (Realtime sends only the primary
// key for deletes under RLS).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/network/row_change.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';

const _me = 'u1';
const _partner = 'u2';

class _Session extends CoupleSession {
  @override
  String? get userId => _me;
}

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(_Session())],
  );
  addTearDown(container.dispose);
  container.listen(loveChatControllerProvider, (_, _) {});
  container.listen(noteitControllerProvider, (_, _) {});
  return container;
}

Map<String, dynamic> _row(
  String id,
  String type,
  String content, {
  String sender = _partner,
  int minutesAgo = 0,
}) => {
  'id': id,
  'couple_id': 'c1',
  'type': type,
  'content': content,
  'sender_id': sender,
  'created_at': DateTime.now()
      .toUtc()
      .subtract(Duration(minutes: minutesAgo))
      .toIso8601String(),
};

RowChange _insert(Map<String, dynamic> row) =>
    RowChange(type: RowChangeType.insert, newRecord: row);
RowChange _update(Map<String, dynamic> row) =>
    RowChange(type: RowChangeType.update, newRecord: row);
RowChange _delete(String id) =>
    RowChange(type: RowChangeType.delete, oldRecord: {'id': id});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'user_id': _me}));

  group('LoveChatController.onRowChange', () {
    test('inserts chat rows newest-first and ignores note-it rows', () async {
      final container = _container();
      await Future<void>.delayed(Duration.zero);
      final chat = container.read(loveChatControllerProvider.notifier);
      expect(chat.usesRowChanges, isTrue);

      chat.onRowChange(_insert(_row('m1', 'chat', 'older', minutesAgo: 5)));
      chat.onRowChange(_insert(_row('m2', 'chat', 'newer')));
      chat.onRowChange(_insert(_row('d1', 'drawing', 'strokes')));

      final ids = container
          .read(loveChatControllerProvider)
          .messages
          .map((m) => m.id);
      expect(ids.take(2), ['m2', 'm1']);
      expect(ids, isNot(contains('d1')));
    });

    test('an update replaces in place; my echo does not duplicate', () async {
      final container = _container();
      await Future<void>.delayed(Duration.zero);
      final chat = container.read(loveChatControllerProvider.notifier);

      chat.onRowChange(_insert(_row('m1', 'chat', 'hi', sender: _me)));
      chat.onRowChange(_update(_row('m1', 'chat', 'hi (edited)', sender: _me)));

      final m1 = container
          .read(loveChatControllerProvider)
          .messages
          .where((m) => m.id == 'm1');
      expect(m1, hasLength(1));
      expect(m1.single.content, 'hi (edited)');
      expect(m1.single.senderId, 'you');
    });

    test('a delete (primary key only) removes the message', () async {
      final container = _container();
      await Future<void>.delayed(Duration.zero);
      final chat = container.read(loveChatControllerProvider.notifier);
      chat.onRowChange(_insert(_row('m1', 'chat', 'bye')));
      final before = container.read(loveChatControllerProvider).messages.length;

      chat.onRowChange(_delete('m1'));
      chat.onRowChange(_delete('not-mine'));

      final after = container.read(loveChatControllerProvider).messages;
      expect(after.length, before - 1);
      expect(after.map((m) => m.id), isNot(contains('m1')));
    });

    test('stays capped at maxLocalMessages, keeping the newest', () async {
      final container = _container();
      await Future<void>.delayed(Duration.zero);
      final chat = container.read(loveChatControllerProvider.notifier);
      const n = LoveChatController.maxLocalMessages + 5;
      for (var i = 0; i < n; i++) {
        chat.onRowChange(
          _insert(_row('m$i', 'chat', 'line $i', minutesAgo: n - i)),
        );
      }

      final messages = container.read(loveChatControllerProvider).messages;
      expect(messages, hasLength(LoveChatController.maxLocalMessages));
      expect(messages.first.id, 'm${n - 1}');
    });
  });

  group('NoteitController.onRowChange', () {
    test(
      'applies note-it rows, ignores chat, handles update and delete',
      () async {
        final container = _container();
        await Future<void>.delayed(Duration.zero);
        final notes = container.read(noteitControllerProvider.notifier);
        expect(notes.usesRowChanges, isTrue);

        notes.onRowChange(_insert(_row('n1', 'drawing', 'a', minutesAgo: 10)));
        notes.onRowChange(_insert(_row('n2', 'text', 'b')));
        notes.onRowChange(_insert(_row('m1', 'chat', 'not a note')));
        notes.onRowChange(_update(_row('n1', 'drawing', 'a2', minutesAgo: 10)));

        var ids = container
            .read(noteitControllerProvider)
            .notes
            .map((n) => n.id);
        expect(ids, containsAllInOrder(['n2', 'n1']));
        expect(ids, isNot(contains('m1')));
        final n1 = container
            .read(noteitControllerProvider)
            .notes
            .where((n) => n.id == 'n1');
        expect(n1.single.content, 'a2');

        notes.onRowChange(_delete('n2'));
        ids = container.read(noteitControllerProvider).notes.map((n) => n.id);
        expect(ids, isNot(contains('n2')));
        expect(ids, contains('n1'));
      },
    );
  });
}
