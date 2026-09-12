// Widget tests for GiftRemindersScreen, written before extracting its ~4
// _buildX methods and its inline `_showReminderSheet`
// (showModalBottomSheet + StatefulBuilder closure) into real widget
// classes -- these pin the screen's current rendered behavior so the
// extraction can be verified rather than assumed safe.
//
// GiftReminderController is seeded through a subclass whose build() returns
// a fixed state, so no Supabase client or realtime subscription is
// involved -- the same technique calendar_screen_test.dart uses.
// addReminder/updateReminder/toggleReminder/deleteReminder are exercised
// for real (not mocked) since they all apply their local state change
// unconditionally when coupleId is null, which it is for every seeded
// state here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/gift_reminders/domain/entities/gift_reminder_model.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_controller.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_state.dart';
import 'package:days_together/features/gift_reminders/presentation/pages/gift_reminders_screen.dart';

class _SeededGiftReminder extends GiftReminderController {
  _SeededGiftReminder(this._seed);
  final GiftReminderState _seed;
  @override
  GiftReminderState build() => _seed;
}

Future<void> _pump(
  WidgetTester tester, {
  GiftReminderState giftReminder = const GiftReminderState(
    reminders: [],
    isLoading: false,
  ),
}) async {
  // The list of reminder cards overflows the default 800x600 test surface --
  // a real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(CoupleSession()),
        giftReminderControllerProvider.overrideWith(
          () => _SeededGiftReminder(giftReminder),
        ),
      ],
      child: const MaterialApp(home: GiftRemindersScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GiftRemindersScreen', () {
    testWidgets('shows the empty state with no reminders', (tester) async {
      await _pump(tester);

      expect(find.text('Never forget a date.'), findsOneWidget);
      expect(
        find.text(
          'Add birthdays, anniversaries, or special surprise counters.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders a reminder card with its countdown', (tester) async {
      await _pump(
        tester,
        giftReminder: GiftReminderState(
          isLoading: false,
          reminders: [
            GiftReminder(
              title: "Partner's Birthday",
              date: DateTime.now().add(const Duration(days: 10)),
            ),
          ],
        ),
      );

      expect(find.text("Partner's Birthday"), findsOneWidget);
      expect(find.textContaining('days left'), findsOneWidget);
    });

    testWidgets('adding a new reminder shows it in the list', (tester) async {
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('🎁 New Gift Reminder'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(
          TextField,
          "e.g. Partner's Birthday, Valentine's Day",
        ),
        'Anniversary Dinner',
      );
      await tester.tap(find.text('Select Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Reminder'));
      await tester.pumpAndSettle();

      expect(find.text('🎁 New Gift Reminder'), findsNothing);
      expect(find.text('Anniversary Dinner'), findsOneWidget);
    });

    testWidgets('editing a reminder updates its title', (tester) async {
      await _pump(
        tester,
        giftReminder: GiftReminderState(
          isLoading: false,
          reminders: [
            GiftReminder(
              title: "Partner's Birthday",
              date: DateTime.now().add(const Duration(days: 10)),
            ),
          ],
        ),
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('🎁 Edit Gift Reminder'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, "Partner's Birthday"),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, "Partner's Birthday"),
        "Partner's Big Day",
      );
      await tester.tap(find.text('Update Reminder'));
      await tester.pumpAndSettle();

      expect(find.text("Partner's Birthday"), findsNothing);
      expect(find.text("Partner's Big Day"), findsOneWidget);
    });

    testWidgets('toggling a reminder disables it', (tester) async {
      await _pump(
        tester,
        giftReminder: GiftReminderState(
          isLoading: false,
          reminders: [
            GiftReminder(
              title: "Partner's Birthday",
              date: DateTime.now().add(const Duration(days: 10)),
            ),
          ],
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final toggled = tester.widget<Switch>(find.byType(Switch));
      expect(toggled.value, isFalse);
    });

    testWidgets('deleting a reminder confirms, then removes it', (
      tester,
    ) async {
      await _pump(
        tester,
        giftReminder: GiftReminderState(
          isLoading: false,
          reminders: [
            GiftReminder(
              title: "Partner's Birthday",
              date: DateTime.now().add(const Duration(days: 10)),
            ),
          ],
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Delete Reminder?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text("Partner's Birthday"), findsNothing);
      expect(find.text('Never forget a date.'), findsOneWidget);
    });
  });
}
