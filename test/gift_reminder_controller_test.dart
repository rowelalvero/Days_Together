// Tests for GiftReminderController (Phase 6a of the architecture migration,
// the second of the 12 domain providers ported to Riverpod). No network:
// coupleSessionProvider is overridden with an unpaired CoupleSession()
// throughout (coupleId == null), matching bucket_list_controller_test.dart's
// convention -- these tests exercise the local-only write path.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_controller.dart';
import 'package:days_together/providers/couple_session.dart';

/// giftReminderControllerProvider is `autoDispose` -- see
/// bucket_list_controller_test.dart's identical helper doc comment for why
/// a persistent `container.listen` is required, not just `container.read`.
ProviderContainer _unpairedContainer() {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
  );
  container.listen(giftReminderControllerProvider, (prev, next) {});
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GiftReminderController', () {
    test('build() starts empty when there is no cached data', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(giftReminderControllerProvider);
      expect(state.reminders, isEmpty);
      expect(state.isLoading, false);
    });

    test('addReminder appends locally and persists when unpaired', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      await container.read(giftReminderControllerProvider.notifier).addReminder(
            "Mom's birthday",
            DateTime(2026, 12, 1),
          );

      final state = container.read(giftReminderControllerProvider);
      expect(state.reminders, hasLength(1));
      expect(state.reminders.first.title, "Mom's birthday");

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('gift_reminders'), contains("Mom's birthday"));
    });

    test('toggleReminder flips isEnabled when unpaired', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(giftReminderControllerProvider.notifier);

      await notifier.addReminder('Anniversary', DateTime(2026, 9, 1));
      final id = container.read(giftReminderControllerProvider).reminders.first.id;

      await notifier.toggleReminder(id);
      expect(container.read(giftReminderControllerProvider).reminders.first.isEnabled, false);

      await notifier.toggleReminder(id);
      expect(container.read(giftReminderControllerProvider).reminders.first.isEnabled, true);
    });

    test('updateReminder updates title/date locally when unpaired', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(giftReminderControllerProvider.notifier);

      await notifier.addReminder('Old title', DateTime(2026, 1, 1));
      final id = container.read(giftReminderControllerProvider).reminders.first.id;

      await notifier.updateReminder(id, title: 'New title', date: DateTime(2026, 2, 2));

      final reminder = container.read(giftReminderControllerProvider).reminders.first;
      expect(reminder.title, 'New title');
      expect(reminder.date, DateTime(2026, 2, 2));
    });

    test('deleteReminder removes locally when unpaired', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(giftReminderControllerProvider.notifier);

      await notifier.addReminder('Keep', DateTime(2026, 3, 3));
      await notifier.addReminder('Remove me', DateTime(2026, 4, 4));
      final idToRemove = container
          .read(giftReminderControllerProvider)
          .reminders
          .firstWhere((r) => r.title == 'Remove me')
          .id;

      await notifier.deleteReminder(idToRemove);

      final state = container.read(giftReminderControllerProvider);
      expect(state.reminders, hasLength(1));
      expect(state.reminders.first.title, 'Keep');
    });

    test('purgeCache clears reminders and the SharedPreferences cache', () async {
      final container = _unpairedContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(giftReminderControllerProvider.notifier);
      await notifier.addReminder('Something', DateTime(2026, 5, 5));

      await notifier.purgeCache();

      final state = container.read(giftReminderControllerProvider);
      expect(state.reminders, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('gift_reminders'), isFalse);
    });
  });
}
