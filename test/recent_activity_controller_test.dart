// Tests for RecentActivityController (Phase 6b-4 of the architecture
// migration, replacing RecentActivityProvider). No CoupleSession dependency
// -- the original provider never had one either, since it wraps
// RecentActivityService's local-database-backed ValueNotifier, not a
// couple-scoped Supabase table. `init()`'s database call fails gracefully
// in a unit test environment (no sqflite plugin registered), matching
// production's own try/catch-and-log behavior on a real device with no
// database yet -- these tests exercise that same graceful-failure path.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/features/dashboard/recent_activity_controller.dart';
import 'package:days_together/models/local_activity_model.dart';
import 'package:days_together/services/recent_activity_service.dart';

void main() {
  group('RecentActivityController', () {
    test('build() reflects RecentActivityService.activitiesNotifier\'s current value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(recentActivityControllerProvider);
      expect(state.activities, RecentActivityService.instance.activitiesNotifier.value);
    });

    test('isLoading flips back to false once init() resolves (even on its graceful-failure path)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(recentActivityControllerProvider, (prev, next) {});

      await Future.delayed(Duration.zero);

      expect(container.read(recentActivityControllerProvider).isLoading, false);
    });

    test('state updates when RecentActivityService.activitiesNotifier changes externally', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(recentActivityControllerProvider, (prev, next) {});
      await Future.delayed(Duration.zero);

      final activity = LocalActivity(
        id: 'test-1',
        activityType: 'updated',
        title: 'Test activity',
        description: 'A test activity',
        icon: '✨',
        timestamp: DateTime.now(),
        initiatedByCurrentUser: true,
      );
      addTearDown(() => RecentActivityService.instance.activitiesNotifier.value = []);
      RecentActivityService.instance.activitiesNotifier.value = [activity];

      expect(container.read(recentActivityControllerProvider).activities, [activity]);
    });
  });
}
