// Widget tests for NotificationSettingsScreen, written before extracting
// its inline section cards and _buildX methods into real widget classes --
// these pin the screen's current rendered behavior so the extraction can
// be verified rather than assumed safe.
//
// No switch or time-picker is ever tapped in this suite:
// NotificationPreferencesController.updatePreference always calls
// Supabase.instance.client directly (unlike this app's other feature
// controllers, it has no coupleId-null local-only branch), so exercising
// it for real would hit a live Supabase client this test environment never
// initializes. Disabled-switch behavior (muteAll, quiet hours) is instead
// verified by reading each SwitchListTile's onChanged directly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/settings/domain/entities/notification_preferences_model.dart';
import 'package:days_together/features/settings/notification_preferences_controller.dart';
import 'package:days_together/features/settings/notification_preferences_state.dart';
import 'package:days_together/features/settings/presentation/pages/notification_settings_screen.dart';

class _SeededPrefs extends NotificationPreferencesController {
  _SeededPrefs(this._seed);
  final NotificationPreferencesState _seed;
  @override
  NotificationPreferencesState build() => _seed;
}

Future<void> _pump(
  WidgetTester tester, {
  NotificationPreferencesState state = const NotificationPreferencesState(),
}) async {
  // The three preference cards overflow the default 800x600 test surface --
  // a real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationPreferencesControllerProvider.overrideWith(
          () => _SeededPrefs(state),
        ),
      ],
      child: const MaterialApp(home: NotificationSettingsScreen()),
    ),
  );
  if (state.preferences == null) {
    // The loading state's CircularProgressIndicator is indeterminate and
    // never settles.
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationSettingsScreen', () {
    testWidgets('shows a spinner while preferences have not loaded', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('GLOBAL PREFERENCES'), findsNothing);
    });

    testWidgets('renders all three section headers once loaded', (
      tester,
    ) async {
      await _pump(
        tester,
        state: NotificationPreferencesState(
          preferences: NotificationPreferences(userId: 'user-1'),
        ),
      );

      // Small-caps to match this app's other settings section headings
      // (SettingsSectionHeader) -- the widget uppercases the title it is
      // given, so these are the rendered strings.
      expect(find.text('GLOBAL PREFERENCES'), findsOneWidget);
      expect(find.text('QUIET HOURS'), findsOneWidget);
      expect(find.text('FEATURE NOTIFICATIONS'), findsOneWidget);
    });

    testWidgets('renders a representative tile from each card with its value', (
      tester,
    ) async {
      await _pump(
        tester,
        state: NotificationPreferencesState(
          preferences: NotificationPreferences(
            userId: 'user-1',
            soundEnabled: true,
            chatEnabled: false,
          ),
        ),
      );

      expect(find.text('Mute All Notifications'), findsOneWidget);
      expect(find.text('Enable Quiet Hours'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);

      final chatTile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Chat'),
      );
      expect(chatTile.value, isFalse);
    });

    testWidgets('muteAll disables the dependent switches', (tester) async {
      await _pump(
        tester,
        state: NotificationPreferencesState(
          preferences: NotificationPreferences(userId: 'user-1', muteAll: true),
        ),
      );

      final soundTile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Play Sound'),
      );
      expect(soundTile.onChanged, isNull);

      final chatTile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Chat'),
      );
      expect(chatTile.onChanged, isNull);
    });

    testWidgets('quiet hours start/end rows are hidden when disabled', (
      tester,
    ) async {
      await _pump(
        tester,
        state: NotificationPreferencesState(
          preferences: NotificationPreferences(
            userId: 'user-1',
            quietHoursEnabled: false,
          ),
        ),
      );

      expect(find.text('Start Time'), findsNothing);
      expect(find.text('End Time'), findsNothing);
    });

    testWidgets('quiet hours start/end rows show their times when enabled', (
      tester,
    ) async {
      await _pump(
        tester,
        state: NotificationPreferencesState(
          preferences: NotificationPreferences(
            userId: 'user-1',
            quietHoursEnabled: true,
            quietHoursStart: '23:00',
            quietHoursEnd: '08:00',
          ),
        ),
      );

      expect(find.text('Start Time'), findsOneWidget);
      expect(find.text('23:00'), findsOneWidget);
      expect(find.text('End Time'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
    });
  });
}
