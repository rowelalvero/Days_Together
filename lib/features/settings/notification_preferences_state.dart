import 'package:days_together/core/errors/app_failure.dart';
import 'package:days_together/features/settings/domain/entities/notification_preferences_model.dart';

/// State for `NotificationPreferencesController` (Phase 6a of the
/// architecture migration) -- a direct Riverpod port of
/// `NotificationPreferencesProvider`'s fields, since extended with
/// [failure].
class NotificationPreferencesState {
  final NotificationPreferences? preferences;
  final bool isLoading;

  /// The last write that failed, or null. Set by
  /// `NotificationPreferencesController.updatePreference` when the Supabase
  /// upsert throws, and cleared once the UI has shown it (see
  /// `clearFailure`).
  ///
  /// Exists because a failed toggle used to be invisible: the write ran
  /// before the local state update, so on failure the switch simply never
  /// moved and nothing was reported -- the user could not tell a silently
  /// dropped write from a slow one.
  final AppFailure? failure;

  const NotificationPreferencesState({
    this.preferences,
    this.isLoading = false,
    this.failure,
  });

  NotificationPreferencesState copyWith({
    Object? preferences = _unset,
    bool? isLoading,
    Object? failure = _unset,
  }) {
    return NotificationPreferencesState(
      preferences: identical(preferences, _unset)
          ? this.preferences
          : preferences as NotificationPreferences?,
      isLoading: isLoading ?? this.isLoading,
      failure: identical(failure, _unset)
          ? this.failure
          : failure as AppFailure?,
    );
  }
}

const Object _unset = Object();
