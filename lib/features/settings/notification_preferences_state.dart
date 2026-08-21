import 'package:days_together/models/notification_preferences_model.dart';

/// State for `NotificationPreferencesController` (Phase 6a of the
/// architecture migration) -- a direct Riverpod port of
/// `NotificationPreferencesProvider`'s fields.
class NotificationPreferencesState {
  final NotificationPreferences? preferences;
  final bool isLoading;

  const NotificationPreferencesState({this.preferences, this.isLoading = false});

  NotificationPreferencesState copyWith({
    Object? preferences = _unset,
    bool? isLoading,
  }) {
    return NotificationPreferencesState(
      preferences: identical(preferences, _unset) ? this.preferences : preferences as NotificationPreferences?,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

const Object _unset = Object();
