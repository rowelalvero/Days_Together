import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/models/local_activity_model.dart';
import 'package:days_together/services/recent_activity_service.dart';

/// The Riverpod-native replacement for `RecentActivityProvider` (Phase 6b-4
/// of the architecture migration). No `CoupleSession` dependency -- the
/// original `RecentActivityProvider` never had one either (it's a thin
/// wrapper over `RecentActivityService`'s own local-database-backed
/// `ValueNotifier`, not a couple-scoped Supabase table).
///
/// `logLocalActivity`/`clearAllActivities` were not ported forward:
/// confirmed zero callers anywhere in `lib/` or `test/` -- only the
/// `activities`/`isLoading` reads (`recent_activity_feed.dart`) were ever
/// actually used, matching this migration's established "don't port dead
/// API surface forward" rule (see e.g. Phase 5 unit 2's 10 dead license
/// setters, Phase 5 unit 4's `togglePremium()`).
class RecentActivityState {
  final List<LocalActivity> activities;
  final bool isLoading;

  const RecentActivityState({this.activities = const [], this.isLoading = false});
}

class RecentActivityController extends Notifier<RecentActivityState> {
  @override
  RecentActivityState build() {
    RecentActivityService.instance.activitiesNotifier.addListener(_onServiceActivitiesChanged);
    ref.onDispose(() {
      RecentActivityService.instance.activitiesNotifier.removeListener(_onServiceActivitiesChanged);
    });
    _initService();
    // isLoading starts true directly in this returned value, not via a
    // `state =` write inside _initService() -- that would run synchronously
    // (no `await` precedes it) as part of this build() call, before
    // build() has returned and Riverpod has anywhere to write the state to.
    return RecentActivityState(
      activities: RecentActivityService.instance.activitiesNotifier.value,
      isLoading: true,
    );
  }

  void _onServiceActivitiesChanged() {
    state = RecentActivityState(
      activities: RecentActivityService.instance.activitiesNotifier.value,
      isLoading: state.isLoading,
    );
  }

  Future<void> _initService() async {
    await RecentActivityService.instance.init();
    if (!ref.mounted) return;
    state = RecentActivityState(
      activities: RecentActivityService.instance.activitiesNotifier.value,
      isLoading: false,
    );
  }
}

final recentActivityControllerProvider =
    NotifierProvider<RecentActivityController, RecentActivityState>(
  RecentActivityController.new,
);
