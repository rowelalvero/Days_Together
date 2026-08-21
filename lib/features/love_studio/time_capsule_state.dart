import 'package:days_together/models/time_capsule_model.dart';

/// State for `TimeCapsuleController` (Phase 6a of the architecture
/// migration) -- a direct Riverpod port of `TimeCapsuleProvider`'s
/// `_capsules`/`_isLoading` fields.
class TimeCapsuleState {
  final List<TimeCapsule> capsules;
  final bool isLoading;

  const TimeCapsuleState({this.capsules = const [], this.isLoading = true});

  TimeCapsuleState copyWith({List<TimeCapsule>? capsules, bool? isLoading}) {
    return TimeCapsuleState(
      capsules: capsules ?? this.capsules,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<TimeCapsule> get lockedCapsules => capsules.where((c) => !c.isOpened && !c.canOpen).toList();
  List<TimeCapsule> get openableCapsules => capsules.where((c) => !c.isOpened && c.canOpen).toList();
  List<TimeCapsule> get openedCapsules => capsules.where((c) => c.isOpened).toList();
}
