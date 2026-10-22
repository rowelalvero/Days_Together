// SupabaseLifecycleNotifier session-change correctness (audit F-15, F-16).
//
// F-15: a sync started for one user/couple used to write its result even if
// the session had moved on by the time it returned -- a slow response for A
// overwrote B's freshly loaded state, or refilled the state purgeCache() had
// just emptied on logout. The probe controller below uses the real mixin;
// completers stand in for the network so the test controls arrival order.
//
// F-16: removeAllChannels() (every non-refresh auth change) closes every
// underlying channel; the shared stream used to stay cached but silent and
// nothing re-subscribed. Now the manager ends its streams and the controller
// re-subscribes.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/network/realtime_subscription_manager.dart';
import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/core/session/couple_session.dart';

class _Session extends CoupleSession {
  _Session(this._userId, this._coupleId);
  final String? _userId;
  final String? _coupleId;

  /// Flipped on only after construction has settled: while it is true the
  /// real constructor would try to open a Supabase auth listener.
  bool online = false;

  @override
  String? get userId => _userId;
  @override
  String? get coupleId => _coupleId;
  @override
  bool get isSupabaseAvailable => online;
}

class _Probe extends Notifier<List<String>>
    with SupabaseLifecycleNotifier<List<String>> {
  final Map<String, Completer<List<String>>> pending = {};

  @override
  String get tableName => 'probe_table';

  @override
  List<String> build() {
    ref.keepAlive();
    return const [];
  }

  @override
  Future<void> syncInitialData() async {
    // The same shape every feature controller uses.
    final generation = sessionGeneration;
    final response = pending[coupleId!] = Completer<List<String>>();
    final rows = await response.future;
    if (isStale(generation)) return;
    state = rows;
  }

  @override
  Future<void> purgeCache() async => state = const [];

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {}
}

final _probeProvider = NotifierProvider<_Probe, List<String>>(
  _Probe.new,
  dependencies: [coupleSessionProvider],
);

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(_Session(null, null))],
  );
  addTearDown(container.dispose);
  container.listen(_probeProvider, (_, _) {});
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('F-15: stale sync responses are dropped', () {
    test('A\'s slow response cannot overwrite B\'s state', () async {
      final container = _container();
      final probe = container.read(_probeProvider.notifier);

      unawaited(probe.updateSession(_Session('user-a', 'couple-a')));
      unawaited(probe.updateSession(_Session('user-b', 'couple-b')));
      await Future<void>.delayed(Duration.zero);

      probe.pending['couple-b']!.complete(['B memory']);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(_probeProvider), ['B memory']);

      // A's request finally returns.
      probe.pending['couple-a']!.complete(['A memory']);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(_probeProvider), ['B memory']);
    });

    test(
      'a response landing after logout cannot refill the purged state',
      () async {
        final container = _container();
        final probe = container.read(_probeProvider.notifier);

        unawaited(probe.updateSession(_Session('user-a', 'couple-a')));
        await Future<void>.delayed(Duration.zero);
        await probe.updateSession(_Session(null, null)); // logout -> purge
        expect(container.read(_probeProvider), isEmpty);

        probe.pending['couple-a']!.complete(['A memory']);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(_probeProvider), isEmpty);
      },
    );

    test('a current response is still applied (not vacuous)', () async {
      final container = _container();
      final probe = container.read(_probeProvider.notifier);

      unawaited(probe.updateSession(_Session('user-a', 'couple-a')));
      await Future<void>.delayed(Duration.zero);
      probe.pending['couple-a']!.complete(['A memory']);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(_probeProvider), ['A memory']);
    });

    test(
      'every lifecycle controller\'s load path uses the staleness guard',
      () {
        final offenders = <String>[];
        var checked = 0;
        for (final file in Directory(
          'lib/features',
        ).listSync(recursive: true).whereType<File>()) {
          final source = file.readAsStringSync();
          if (!source.contains('with SupabaseLifecycleNotifier')) continue;
          checked++;
          if (!source.contains('final generation = sessionGeneration;') ||
              !source.contains('isStale(generation)')) {
            offenders.add(file.path);
          }
        }
        expect(checked, greaterThanOrEqualTo(10));
        expect(offenders, isEmpty);
      },
    );
  });

  group('F-16: realtime survives removeAllChannels()', () {
    test('reset() ends shared streams and forgets their keys', () async {
      const table = 'timeline_items';
      const couple = 'f16-reset-1';
      var done = false;
      final sub = RealtimeSubscriptionManager.instance
          .getStream(tableName: table, coupleId: couple)
          .listen((_) {}, onError: (_) {}, onDone: () => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(
        RealtimeSubscriptionManager.instance.hasActiveStream(
          tableName: table,
          coupleId: couple,
        ),
        isTrue,
      );

      RealtimeSubscriptionManager.instance.reset();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue, reason: 'listeners must learn the stream ended');
      expect(
        RealtimeSubscriptionManager.instance.hasActiveStream(
          tableName: table,
          coupleId: couple,
        ),
        isFalse,
      );
      await sub.cancel();
    });

    test('a controller re-subscribes after its stream is ended', () async {
      final session = _Session('user-r', 'f16-couple-r');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      session.online = true;
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(session)],
      );
      addTearDown(container.dispose);
      container.listen(_probeProvider, (_, _) {});
      final probe = container.read(_probeProvider.notifier);
      bool active() => RealtimeSubscriptionManager.instance.hasActiveStream(
        tableName: 'probe_table',
        coupleId: 'f16-couple-r',
      );

      unawaited(probe.updateSession(session));
      await Future<void>.delayed(Duration.zero);
      probe.pending['f16-couple-r']!.complete(const []);
      await Future<void>.delayed(Duration.zero);
      expect(active(), isTrue);

      // What CoupleSession now does right after removeAllChannels().
      RealtimeSubscriptionManager.instance.reset();
      await Future<void>.delayed(Duration.zero);
      expect(active(), isFalse);

      // First resubscribe after a 1 s backoff.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(active(), isTrue);
    });
  });
}
