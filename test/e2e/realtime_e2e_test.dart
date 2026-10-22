// End-to-end Realtime checks against a REAL Supabase stack (the local one).
//
// pgTAP can test realtime.messages policies, but not how the Realtime
// server itself authorises a join or routes postgres_changes -- and that
// difference mattered: the first version of the private presence policies
// passed every pgTAP check yet the real server refused every join (it
// requires broadcast READ to join a private channel at all). These tests
// talk to the real server with real users.
//
// Skipped unless pointed at a stack:
//   eval "$(supabase status -o env | grep -E '^(API_URL|ANON_KEY)=')"
//   E2E_SUPABASE_URL="$API_URL" E2E_SUPABASE_ANON_KEY="$ANON_KEY" \
//     flutter test test/e2e/realtime_e2e_test.dart
// Never run it against a hosted project: it signs up throwaway users.
//
// No TestWidgetsFlutterBinding: that binding fakes all HTTP, and this test
// needs the real network.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/network/row_change.dart';
import 'package:days_together/core/network/supabase_sync_service.dart';
import 'package:days_together/core/session/partner_presence.dart';
import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';

final _url = Platform.environment['E2E_SUPABASE_URL'];
final _anonKey = Platform.environment['E2E_SUPABASE_ANON_KEY'];
final _skip = (_url == null || _anonKey == null)
    ? 'set E2E_SUPABASE_URL and E2E_SUPABASE_ANON_KEY to run'
    : null;

const _settle = Duration(seconds: 2);

class _User {
  _User(this.client, this.id);
  final SupabaseClient client;
  final String id;
}

Future<_User> _signUp(String tag) async {
  final client = SupabaseClient(
    _url!,
    _anonKey!,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  final email = '$tag-${DateTime.now().microsecondsSinceEpoch}@e2e.local';
  final res = await client.auth.signUp(
    email: email,
    password: 'e2e-password-1',
  );
  client.realtime.setAuth(res.session!.accessToken);
  return _User(client, res.user!.id);
}

/// Pairs [a] and [b] through the real RPCs; returns the couple id.
Future<String> _pair(_User a, _User b) async {
  final ws = await a.client.rpc('create_relationship_workspace');
  final joined = await b.client.rpc(
    'join_relationship_with_code',
    params: {'p_pairing_code': ws['pairing_code']},
  );
  expect(joined['success'], isTrue);
  return ws['couple_id'] as String;
}

/// Joins the couple presence channel exactly as PartnerPresence does: a
/// presence binding registered BEFORE subscribe, private channel, its topic.
Future<(RealtimeChannel, RealtimeSubscribeStatus)> _joinPresence(
  _User user,
  String coupleId, {
  bool private = true,
}) {
  final channel = user.client.channel(
    presenceTopicFor(coupleId),
    opts: RealtimeChannelConfig(private: private),
  );
  final status = Completer<RealtimeSubscribeStatus>();
  channel
    ..onPresenceSync((_) {})
    ..subscribe((s, [_]) {
      if (!status.isCompleted) status.complete(s);
    });
  return status.future
      .timeout(const Duration(seconds: 8))
      .then((s) => (channel, s));
}

Set<String> _present(RealtimeChannel channel) => {
  for (final state in channel.presenceState())
    for (final p in state.presences) p.payload['user_id'] as String,
};

/// Subscribes via the app's real SupabaseSyncService code path.
Future<(List<RowChange>, Future<void> Function())> _rowChanges(
  _User user,
  String coupleId, {
  String table = 'love_notes',
}) async {
  final changes = <RowChange>[];
  final subscribed = Completer<void>();
  final close = SupabaseSyncService.instance.subscribeToCoupleRowChanges(
    client: user.client,
    tableName: table,
    coupleId: coupleId,
    onChange: changes.add,
    onSubscribed: () {
      if (!subscribed.isCompleted) subscribed.complete();
    },
    onError: (e) {
      if (!subscribed.isCompleted) subscribed.completeError(e);
    },
    onClosed: () {},
  );
  await subscribed.future.timeout(const Duration(seconds: 8));
  return (changes, close);
}

void main() {
  late _User a;
  late _User b;
  late _User outsider;
  late String coupleId;

  setUpAll(() async {
    if (_skip != null) return;
    a = await _signUp('a');
    b = await _signUp('b');
    outsider = await _signUp('c');
    coupleId = await _pair(a, b);
  });

  tearDownAll(() async {
    if (_skip != null) return;
    for (final u in [a, b, outsider]) {
      await u.client.removeAllChannels();
      await u.client.dispose();
    }
  });

  group('love_notes row changes (audit F-18)', () {
    test(
      'partner receives insert/update/delete; an outsider gets no content',
      () async {
        final (partnerChanges, closePartner) = await _rowChanges(b, coupleId);
        // The outsider subscribes with the SAME couple filter -- RLS must
        // still withhold every change, deletes included.
        final (outsiderChanges, closeOutsider) = await _rowChanges(
          outsider,
          coupleId,
        );
        await Future<void>.delayed(_settle);

        // Spaced like real use: Realtime checks RLS for an insert/update when
        // it processes the change, so a row deleted within milliseconds of
        // being written can have its insert/update dropped (only the delete,
        // which carries just the id, survives).
        Future<void> untilPartnerHas(int n) async {
          for (var i = 0; i < 50 && partnerChanges.length < n; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }

        final inserted = await a.client
            .from('love_notes')
            .insert({
              'couple_id': coupleId,
              'type': 'chat',
              'content': 'hello',
              'sender_id': a.id,
            })
            .select('id')
            .single();
        final id = inserted['id'] as String;
        await untilPartnerHas(1);
        await a.client
            .from('love_notes')
            .update({'content': 'hello again'})
            .eq('id', id);
        await untilPartnerHas(2);
        await a.client.from('love_notes').delete().eq('id', id);
        await untilPartnerHas(3);
        await Future<void>.delayed(_settle); // give the outsider every chance

        expect(partnerChanges.map((c) => c.type).toList(), [
          RowChangeType.insert,
          RowChangeType.update,
          RowChangeType.delete,
        ]);
        expect(partnerChanges[0].newRecord['content'], 'hello');
        expect(partnerChanges[1].newRecord['content'], 'hello again');
        expect(partnerChanges[2].id, id, reason: 'delete carries the id');
        // RLS withholds every insert and update from the outsider. Supabase
        // Realtime does NOT apply RLS to deletes (the row no longer exists to
        // check), so a delete may reach anyone subscribed with this couple id
        // -- but carrying the primary key only: no content, sender or type.
        // Same as the previous .stream() implementation; recorded as a
        // residual in docs/security/security-invariants.md.
        expect(
          outsiderChanges.where((c) => c.type != RowChangeType.delete),
          isEmpty,
        );
        for (final leaked in outsiderChanges) {
          expect(leaked.newRecord, isEmpty);
          expect(leaked.oldRecord.keys, ['id']);
        }

        await closePartner();
        await closeOutsider();
      },
      skip: _skip,
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });

  group('timeline paging', () {
    test(
      'the page and stats queries page every memory exactly once, in both '
      'orders, with ties on date; outsiders see none',
      () async {
        // Six memories share one exact timestamp, so only the id tiebreak
        // keeps a page boundary from skipping or repeating one.
        const tie = '2024-06-01T12:00:00.123456Z';
        final rows = [
          for (var i = 0; i < 13; i++)
            {
              'couple_id': coupleId,
              'title': 'paging $i',
              'date': i < 6
                  ? tie
                  : DateTime.utc(2023, 1, 1 + i).toIso8601String(),
              // Photos: 3 by network_image_url, 1 by image_path; '' is not.
              'network_image_url': i < 3 ? 'couples/x/timeline/$i.jpg' : null,
              'image_path': i == 3 ? '/local/$i.jpg' : (i == 4 ? '' : null),
            },
        ];
        final inserted = await a.client
            .from('timeline_items')
            .insert(rows)
            .select('id, date');
        final expectedAscending = [...inserted]
          ..sort((x, y) {
            final byDate = DateTime.parse(
              x['date'] as String,
            ).compareTo(DateTime.parse(y['date'] as String));
            return byDate != 0
                ? byDate
                : (x['id'] as String).compareTo(y['id'] as String);
          });
        final ascendingIds = [
          for (final r in expectedAscending) r['id'] as String,
        ];

        Future<List<String>> pageThrough({required bool ascending}) async {
          final seen = <String>[];
          TimelineCursor? cursor;
          while (true) {
            final page = await TimelineController.queryPage(
              b.client,
              coupleId: coupleId,
              ascending: ascending,
              after: cursor,
              limit: 4,
            );
            if (page.isEmpty) return seen;
            seen.addAll(page.map((r) => r['id'] as String));
            cursor = (
              date: DateTime.parse(page.last['date'] as String).toLocal(),
              id: page.last['id'] as String,
            );
          }
        }

        expect(await pageThrough(ascending: true), ascendingIds);
        expect(
          await pageThrough(ascending: false),
          ascendingIds.reversed.toList(),
        );

        final stats = await TimelineController.queryServerStats(
          b.client,
          coupleId: coupleId,
        );
        expect(stats.total, 13);
        expect(stats.photos, 4);
        expect(stats.earliest?['id'], ascendingIds.first);

        // The calendar's month load: every memory in [from, to), paged with
        // the same keyset when a month is large.
        final rangeSeen = <String>[];
        TimelineCursor? rangeCursor;
        while (true) {
          final page = await TimelineController.queryRange(
            b.client,
            coupleId: coupleId,
            from: DateTime.utc(2023),
            to: DateTime.utc(2024),
            after: rangeCursor,
            limit: 3,
          );
          rangeSeen.addAll(page.map((r) => r['id'] as String));
          if (page.length < 3) break;
          rangeCursor = (
            date: DateTime.parse(page.last['date'] as String).toLocal(),
            id: page.last['id'] as String,
          );
        }
        expect(rangeSeen, ascendingIds.take(7).toList());
        final june = await TimelineController.queryRange(
          b.client,
          coupleId: coupleId,
          from: DateTime.utc(2024, 6),
          to: DateTime.utc(2024, 7),
          limit: 500,
        );
        expect(june, hasLength(6));

        // A tapped notification's single-memory load.
        final one = await TimelineController.queryById(
          b.client,
          coupleId: coupleId,
          id: ascendingIds.last,
        );
        expect(one?['id'], ascendingIds.last);
        expect(
          await TimelineController.queryById(
            outsider.client,
            coupleId: coupleId,
            id: ascendingIds.last,
          ),
          isNull,
        );

        final peek = await TimelineController.queryPage(
          outsider.client,
          coupleId: coupleId,
          ascending: true,
          limit: 50,
        );
        expect(peek, isEmpty);

        await a.client
            .from('timeline_items')
            .delete()
            .eq('couple_id', coupleId);
      },
      skip: _skip,
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      'the partner receives a new memory as a single row change',
      () async {
        final (changes, close) = await _rowChanges(
          b,
          coupleId,
          table: 'timeline_items',
        );
        final row = await a.client
            .from('timeline_items')
            .insert({
              'couple_id': coupleId,
              'title': 'live memory',
              'date': DateTime.now().toUtc().toIso8601String(),
            })
            .select('id')
            .single();
        await Future<void>.delayed(_settle);

        final inserts = changes.where((c) => c.type == RowChangeType.insert);
        expect(inserts.map((c) => c.id), [row['id']]);
        expect(inserts.single.newRecord['title'], 'live memory');

        await close();
        await a.client.from('timeline_items').delete().eq('id', row['id']);
      },
      skip: _skip,
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });

  group('love_notes paging (chat history and scrapbook)', () {
    test(
      'chat and scrapbook queries page their own rows exactly once, with '
      'ties on created_at; lookups, counts and ranges are scoped too',
      () async {
        // Half of each kind share one exact timestamp, so only the id
        // tiebreak keeps a page boundary from skipping or repeating a row.
        const tie = '2024-03-01T09:00:00.654321Z';
        final rows = [
          for (var i = 0; i < 12; i++)
            {
              'couple_id': coupleId,
              'type': 'chat',
              'content': 'chat $i',
              'sender_id': a.id,
              'created_at': i < 6
                  ? tie
                  : DateTime.utc(2024, 2, 1 + i).toIso8601String(),
            },
          for (var i = 0; i < 7; i++)
            {
              'couple_id': coupleId,
              'type': i.isEven ? 'text' : 'drawing',
              'content': 'note $i',
              'sender_id': a.id,
              'created_at': i < 4
                  ? tie
                  : DateTime.utc(2023, 7, 1 + i).toIso8601String(),
            },
        ];
        final inserted = await a.client
            .from('love_notes')
            .insert(rows)
            .select('id, type, created_at');

        List<String> newestFirst(bool chat) {
          final r =
              inserted.where((x) => (x['type'] == 'chat') == chat).toList()
                ..sort((x, y) {
                  final byDate = DateTime.parse(
                    y['created_at'] as String,
                  ).compareTo(DateTime.parse(x['created_at'] as String));
                  return byDate != 0
                      ? byDate
                      : (y['id'] as String).compareTo(x['id'] as String);
                });
          return [for (final x in r) x['id'] as String];
        }

        // Chat history, scrolled back page by page.
        final chatSeen = <String>[];
        ChatCursor? chatCursor;
        while (true) {
          final page = await LoveChatController.queryPage(
            b.client,
            coupleId: coupleId,
            before: chatCursor,
            limit: 5,
          );
          if (page.isEmpty) break;
          chatSeen.addAll(page.map((r) => r['id'] as String));
          chatCursor = (
            createdAt: DateTime.parse(page.last['created_at'] as String),
            id: page.last['id'] as String,
          );
        }
        expect(chatSeen, newestFirst(true));

        // Scrapbook history, the same way.
        final notesSeen = <String>[];
        NoteitCursor? noteCursor;
        while (true) {
          final page = await NoteitController.queryPage(
            b.client,
            coupleId: coupleId,
            before: noteCursor,
            limit: 3,
          );
          if (page.isEmpty) break;
          notesSeen.addAll(page.map((r) => r['id'] as String));
          noteCursor = (
            createdAt: DateTime.parse(
              page.last['created_at'] as String,
            ).toLocal(),
            id: page.last['id'] as String,
          );
        }
        expect(notesSeen, newestFirst(false));

        expect(
          await NoteitController.queryCount(b.client, coupleId: coupleId),
          7,
        );

        // By id: a chat row is not a note, and an unknown id is just absent.
        final someNote = newestFirst(false).first;
        final someChat = newestFirst(true).first;
        final byIds = await NoteitController.queryByIds(
          b.client,
          coupleId: coupleId,
          ids: [someNote, someChat, '00000000-0000-0000-0000-000000000000'],
        );
        expect(byIds.map((r) => r['id']), [someNote]);

        final year2023 = await NoteitController.queryRange(
          b.client,
          coupleId: coupleId,
          from: DateTime.utc(2023),
          to: DateTime.utc(2024),
        );
        expect(year2023, hasLength(3));

        // Outsiders see none of it.
        expect(
          await LoveChatController.queryPage(
            outsider.client,
            coupleId: coupleId,
            limit: 50,
          ),
          isEmpty,
        );
        expect(
          await NoteitController.queryByIds(
            outsider.client,
            coupleId: coupleId,
            ids: [someNote],
          ),
          isEmpty,
        );

        await a.client.from('love_notes').delete().eq('couple_id', coupleId);
      },
      skip: _skip,
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });

  group('private couple presence (re-audit R-02)', () {
    test(
      'members join and see each other; outsiders and ex-partners cannot',
      () async {
        final (aCh, aStatus) = await _joinPresence(a, coupleId);
        expect(aStatus, RealtimeSubscribeStatus.subscribed);
        await aCh.track({'user_id': a.id});

        final (bCh, bStatus) = await _joinPresence(b, coupleId);
        expect(bStatus, RealtimeSubscribeStatus.subscribed);
        await Future<void>.delayed(_settle);
        expect(_present(bCh), contains(a.id));

        final (_, outsiderPrivate) = await _joinPresence(outsider, coupleId);
        expect(outsiderPrivate, RealtimeSubscribeStatus.channelError);

        // A public join to the same topic is a DIFFERENT channel: it must
        // not reveal the couple's private presence.
        final (pubCh, _) = await _joinPresence(
          outsider,
          coupleId,
          private: false,
        );
        await Future<void>.delayed(_settle);
        expect(_present(pubCh), isNot(contains(a.id)));

        // After unlinking, B can no longer join.
        await b.client.removeAllChannels();
        await b.client.rpc('disconnect_relationship_workspace');
        final (_, afterUnlink) = await _joinPresence(b, coupleId);
        expect(afterUnlink, RealtimeSubscribeStatus.channelError);
      },
      skip: _skip,
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });
}
