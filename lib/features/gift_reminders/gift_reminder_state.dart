import 'package:days_together/models/gift_reminder_model.dart';

/// State for `GiftReminderController` (Phase 6a of the architecture
/// migration) -- a direct Riverpod port of `GiftReminderProvider`'s
/// `_reminders`/`_isLoading` fields.
class GiftReminderState {
  final List<GiftReminder> reminders;
  final bool isLoading;

  const GiftReminderState({this.reminders = const [], this.isLoading = true});

  GiftReminderState copyWith({List<GiftReminder>? reminders, bool? isLoading}) {
    return GiftReminderState(
      reminders: reminders ?? this.reminders,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<GiftReminder> get upcomingReminders {
    final sorted = List<GiftReminder>.from(reminders)..sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return sorted;
  }
}
