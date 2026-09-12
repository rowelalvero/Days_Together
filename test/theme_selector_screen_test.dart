// Widget tests for ThemeSelectorScreen, written before extracting
// _CustomThemeDesignerState's ~5 _buildX methods into real widget classes
// (and relocating the already-proper _ThemeCard/_CustomThemeDesigner/
// _ModeChip classes out of the screen file) -- these pin the screen's
// current rendered behavior so the extraction can be verified rather than
// assumed safe.
//
// ThemeController is seeded through a subclass whose build() returns a
// fixed state, so no SharedPreferences read is involved -- the same
// technique calendar_screen_test.dart uses.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/features/theme/presentation/pages/theme_selector_screen.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/theme/theme_state.dart';
import 'package:days_together/shared/models/app_settings.dart';

class _SeededTheme extends ThemeController {
  _SeededTheme(this._seed);
  final ThemeState _seed;
  @override
  ThemeState build() => _seed;
}

Future<void> _pump(WidgetTester tester, {required ThemeState theme}) async {
  // The theme grid + custom designer overflow the default 800x600 test
  // surface -- a real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        themeControllerProvider.overrideWith(() => _SeededTheme(theme)),
      ],
      child: const MaterialApp(home: ThemeSelectorScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeSelectorScreen', () {
    testWidgets('renders the theme grid with all preset names', (tester) async {
      await _pump(tester, theme: ThemeState(currentTheme: ThemeType.pink));

      expect(find.text('Themes'), findsOneWidget);
      expect(find.text('Rose Quartz'), findsOneWidget);
      expect(find.text('Midnight Glass'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets(
      'hides the custom designer unless the custom theme is selected',
      (tester) async {
        await _pump(tester, theme: ThemeState(currentTheme: ThemeType.pink));

        expect(find.text('CUSTOM DESIGNER'), findsNothing);
      },
    );

    testWidgets('shows the custom designer when custom theme is selected', (
      tester,
    ) async {
      await _pump(tester, theme: ThemeState(currentTheme: ThemeType.custom));

      expect(find.text('CUSTOM DESIGNER'), findsOneWidget);
      expect(find.text('COLOR SLOTS'), findsOneWidget);
      expect(find.text('PICK A COLOR'), findsOneWidget);
      expect(find.text('MODE'), findsOneWidget);
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
    });

    testWidgets('entering a hex code applies the active color slot', (
      tester,
    ) async {
      await _pump(tester, theme: ThemeState(currentTheme: ThemeType.custom));

      await tester.enterText(
        find.widgetWithText(TextField, 'Enter hex (e.g. FF4D6D)'),
        '00FF00',
      );
      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pumpAndSettle();

      final settings = ProviderScope.containerOf(
        tester.element(find.byType(ThemeSelectorScreen)),
      ).read(themeControllerProvider).settings;
      expect(settings.customPrimaryColor, 0xFF00FF00);
    });

    testWidgets('selecting a different slot then a swatch applies it', (
      tester,
    ) async {
      await _pump(tester, theme: ThemeState(currentTheme: ThemeType.custom));

      await tester.tap(find.text('Secondary'));
      await tester.pumpAndSettle();

      // Two Wraps exist (the slot chips, then the color palette) -- tap the
      // first swatch in the second Wrap, a deterministic target regardless
      // of the palette's exact colors.
      await tester.tap(
        find
            .descendant(
              of: find.byType(Wrap).at(1),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      await tester.pumpAndSettle();

      final settings = ProviderScope.containerOf(
        tester.element(find.byType(ThemeSelectorScreen)),
      ).read(themeControllerProvider).settings;
      expect(settings.customSecondaryColor, isNot(0xFFC44569));
      expect(settings.customPrimaryColor, 0xFFFF6B9D);
    });

    testWidgets('toggling Light mode applies it', (tester) async {
      await _pump(tester, theme: ThemeState(currentTheme: ThemeType.custom));

      final before = ProviderScope.containerOf(
        tester.element(find.byType(ThemeSelectorScreen)),
      ).read(themeControllerProvider).settings;
      expect(before.customIsDark, isTrue);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      final after = ProviderScope.containerOf(
        tester.element(find.byType(ThemeSelectorScreen)),
      ).read(themeControllerProvider).settings;
      expect(after.customIsDark, isFalse);
    });
  });
}
