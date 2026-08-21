// Regression tests for RealtimeSubscriptionManager (Definition-of-Done item
// 19, per ADR-005's validation section and Phase 6a's own roadmap
// checklist): exactly one subscription per table+couple key under two
// concurrent listeners, teardown when the last listener is removed, no
// duplicate subscription on rapid re-subscribe, and full teardown on
// disconnect/logout (exercised here as "every listener cancels").
//
// No network: Supabase.instance throws without Supabase.initialize(), but
// SupabaseSyncService.subscribeToCoupleData already catches that (see its
// own try/catch, forwarding to onError and returning a dummy empty-stream
// subscription) -- so calling .listen() on a manager stream in these tests
// exercises the manager's real dedup/teardown bookkeeping without needing
// a live Supabase connection.
//
// RealtimeSubscriptionManager is a singleton (`instance`), so every test
// uses a distinct coupleId to avoid leaking state between tests via its
// internal maps, since there is no way to reset the singleton between test
// cases. Assertions use `hasActiveStream`/`activeStreamCount`
// (`@visibleForTesting`, added alongside this test) rather than
// `identical()` on the streams `getStream()` returns: `Stream.broadcast()`'s
// own `.stream` getter mints a fresh wrapper object on every access, so two
// `getStream()` calls for the same key are never `identical()` even though
// they deliver from the same underlying controller -- identity comparison
// can't observe the dedup this suite needs to verify.

import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/services/realtime_subscription_manager.dart';

void main() {
  group('RealtimeSubscriptionManager', () {
    test('two concurrent listeners on the same table+couple share exactly one subscription', () async {
      const tableName = 'timeline_items';
      const coupleId = 'rsm-test-shared-1';
      expect(RealtimeSubscriptionManager.instance.hasActiveStream(tableName: tableName, coupleId: coupleId), isFalse);

      final streamA = RealtimeSubscriptionManager.instance.getStream(tableName: tableName, coupleId: coupleId);
      final streamB = RealtimeSubscriptionManager.instance.getStream(tableName: tableName, coupleId: coupleId);

      final subA = streamA.listen((_) {}, onError: (_) {});
      final subB = streamB.listen((_) {}, onError: (_) {});
      await Future.delayed(Duration.zero);

      // Both listeners share the one key -- only one entry exists for it,
      // regardless of how many listeners attached to it.
      expect(RealtimeSubscriptionManager.instance.hasActiveStream(tableName: tableName, coupleId: coupleId), isTrue);

      await subA.cancel();
      await subB.cancel();
    });

    test('two different couples on the same table get independent subscription slots', () async {
      const tableName = 'timeline_items';
      final streamA = RealtimeSubscriptionManager.instance.getStream(tableName: tableName, coupleId: 'rsm-test-couple-a');
      final streamB = RealtimeSubscriptionManager.instance.getStream(tableName: tableName, coupleId: 'rsm-test-couple-b');
      final subA = streamA.listen((_) {}, onError: (_) {});
      final subB = streamB.listen((_) {}, onError: (_) {});
      await Future.delayed(Duration.zero);

      expect(RealtimeSubscriptionManager.instance.hasActiveStream(tableName: tableName, coupleId: 'rsm-test-couple-a'), isTrue);
      expect(RealtimeSubscriptionManager.instance.hasActiveStream(tableName: tableName, coupleId: 'rsm-test-couple-b'), isTrue);

      await subA.cancel();
      await subB.cancel();
      expect(RealtimeSubscriptionManager.instance.hasActiveStream(tableName: tableName, coupleId: 'rsm-test-couple-a'), isFalse);
      expect(RealtimeSubscriptionManager.instance.hasActiveStream(tableName: tableName, coupleId: 'rsm-test-couple-b'), isFalse);
    });

    test('two different tables for the same couple get independent subscription slots', () async {
      const coupleId = 'rsm-test-shared-2';
      final streamA = RealtimeSubscriptionManager.instance.getStream(tableName: 'timeline_items', coupleId: coupleId);
      final streamB = RealtimeSubscriptionManager.instance.getStream(tableName: 'bucket_list', coupleId: coupleId);
      final subA = streamA.listen((_) {}, onError: (_) {});
      final subB = streamB.listen((_) {}, onError: (_) {});
      await Future.delayed(Duration.zero);

      expect(RealtimeSubscriptionManager.instance.hasActiveStream(tableName: 'timeline_items', coupleId: coupleId), isTrue);
      expect(RealtimeSubscriptionManager.instance.hasActiveStream(tableName: 'bucket_list', coupleId: coupleId), isTrue);

      await subA.cancel();
      await subB.cancel();
    });

    test('teardown occurs when the last listener is removed', () async {
      const tableName = 'timeline_items';
      const coupleId = 'rsm-test-teardown';
      final stream = RealtimeSubscriptionManager.instance.getStream(tableName: tableName, coupleId: coupleId);
      final sub = stream.listen((_) {}, onError: (_) {});
      await Future.delayed(Duration.zero);
      expect(RealtimeSubscriptionManager.instance.hasActiveStream(tableName: tableName, coupleId: coupleId), isTrue);

      await sub.cancel();

      expect(
        RealtimeSubscriptionManager.instance.hasActiveStream(tableName: tableName, coupleId: coupleId),
        isFalse,
        reason: 'the last listener cancelling must tear down the shared subscription entry',
      );
    });

    test('cancelling one of two listeners does not tear down a still-shared subscription', () async {
      const tableName = 'love_notes';
      const coupleId = 'rsm-test-partial-cancel';
      final stream = RealtimeSubscriptionManager.instance.getStream(tableName: tableName, coupleId: coupleId);
      final subA = stream.listen((_) {}, onError: (_) {});
      final subB = stream.listen((_) {}, onError: (_) {});
      await Future.delayed(Duration.zero);

      await subA.cancel();
      expect(
        RealtimeSubscriptionManager.instance.hasActiveStream(tableName: tableName, coupleId: coupleId),
        isTrue,
        reason: 'one remaining listener must keep the shared subscription alive',
      );

      await subB.cancel();
      expect(RealtimeSubscriptionManager.instance.hasActiveStream(tableName: tableName, coupleId: coupleId), isFalse);
    });

    test('no duplicate subscription on rapid re-subscribe (tab switch): cancel then immediately re-listen', () async {
      const tableName = 'timeline_items';
      const coupleId = 'rsm-test-rapid-resubscribe';
      final beforeCount = RealtimeSubscriptionManager.instance.activeStreamCount;

      final stream1 = RealtimeSubscriptionManager.instance.getStream(tableName: tableName, coupleId: coupleId);
      final sub1 = stream1.listen((_) {}, onError: (_) {});
      await Future.delayed(Duration.zero);
      await sub1.cancel();

      // Immediately re-subscribe, simulating a widget rebuilding on the
      // next frame after a brief tab switch, with no delay in between.
      final stream2 = RealtimeSubscriptionManager.instance.getStream(tableName: tableName, coupleId: coupleId);
      final sub2 = stream2.listen((_) {}, onError: (_) {});
      await Future.delayed(Duration.zero);

      // The re-subscribe must succeed cleanly and produce exactly one
      // active slot for the key -- not zero (lost), not two (duplicated).
      expect(RealtimeSubscriptionManager.instance.hasActiveStream(tableName: tableName, coupleId: coupleId), isTrue);
      expect(RealtimeSubscriptionManager.instance.activeStreamCount, beforeCount + 1);

      await sub2.cancel();
      expect(RealtimeSubscriptionManager.instance.activeStreamCount, beforeCount);
    });

    test('full teardown across multiple keys: cancelling every listener returns the manager to empty for those keys', () async {
      final baseline = RealtimeSubscriptionManager.instance.activeStreamCount;
      const coupleId = 'rsm-test-full-teardown';
      final tables = ['timeline_items', 'bucket_list', 'love_notes'];

      final subs = [
        for (final table in tables)
          RealtimeSubscriptionManager.instance.getStream(tableName: table, coupleId: coupleId).listen((_) {}, onError: (_) {}),
      ];
      await Future.delayed(Duration.zero);
      expect(RealtimeSubscriptionManager.instance.activeStreamCount, baseline + tables.length);

      // Mirrors disconnect/logout: every controller's subscription is torn
      // down together.
      for (final sub in subs) {
        await sub.cancel();
      }

      expect(RealtimeSubscriptionManager.instance.activeStreamCount, baseline);
      for (final table in tables) {
        expect(RealtimeSubscriptionManager.instance.hasActiveStream(tableName: table, coupleId: coupleId), isFalse);
      }
    });
  });
}
