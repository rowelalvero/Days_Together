// Widget tests for NavItem and UnifiedFloatingBar, extracted from
// LoveStoryScreenState's `_buildNavItem`/`_buildUnifiedFloatingBar`
// (Migration audit item 6).
//
// LoveStoryScreen itself isn't pin-tested here: mounting it would require
// building all 5 real feature tabs (HomeDashboard, TimelineTab,
// TogetherTab, StudioTab, SettingsTab) since IndexedStack keeps every
// child mounted even when hidden, which would mean overriding a large
// fraction of the app's provider graph just to test a nav bar. Instead,
// these tests cover the two pieces that were actually extracted, in
// isolation, with behavior read directly from the original methods before
// they were touched.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as ft show testWidgets;
import 'dart:async' show Completer, runZonedGuarded;
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'package:days_together/shared/models/app_settings.dart' show AppSettings, ThemeType;

import 'package:days_together/app/shell/widgets/nav_item.dart';
import 'package:days_together/app/shell/widgets/unified_floating_bar.dart';
import 'package:days_together/app/theme/theme_manager.dart';

final _theme = ThemeManager.themes.values.first;

void main() {
  group('NavItem', () {
    testWidgets('shows the active icon and accent tint when selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavItem(
              label: 'Home',
              activeIcon: Icons.home_rounded,
              inactiveIcon: Icons.home_outlined,
              isSelected: true,
              theme: _theme,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsNothing);

      final icon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
      expect(icon.color, _theme.accentColor);
    });

    testWidgets('shows the inactive icon when not selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavItem(
              label: 'Home',
              activeIcon: Icons.home_rounded,
              inactiveIcon: Icons.home_outlined,
              isSelected: false,
              theme: _theme,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsNothing);
    });

    testWidgets('tapping invokes onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavItem(
              label: 'Home',
              activeIcon: Icons.home_rounded,
              inactiveIcon: Icons.home_outlined,
              isSelected: false,
              theme: _theme,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(NavItem));
      expect(tapped, isTrue);
    });

    testWidgets('announces its label, button role and selected state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      Future<void> pump(bool selected) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavItem(
              label: 'Home',
              activeIcon: Icons.home_rounded,
              inactiveIcon: Icons.home_outlined,
              isSelected: selected,
              theme: _theme,
              onTap: () {},
            ),
          ),
        ),
      );

      await pump(true);
      expect(
        tester.getSemantics(find.byType(NavItem)),
        matchesSemantics(
          label: 'Home',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );

      await pump(false);
      expect(
        tester.getSemantics(find.byType(NavItem)),
        matchesSemantics(
          label: 'Home',
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('has at least a 48x48 tap target around the 40px-tall pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NavItem(
                label: 'Home',
                activeIcon: Icons.home_rounded,
                inactiveIcon: Icons.home_outlined,
                isSelected: false,
                theme: _theme,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(NavItem));
      expect(size.width, greaterThanOrEqualTo(NavItem.minTapTarget));
      expect(size.height, greaterThanOrEqualTo(NavItem.minTapTarget));
      // The visible pill is unchanged: 24px icon + 8px vertical padding.
      expect(tester.getSize(find.byType(AnimatedContainer)).height, 40);
    });
  });

  group('UnifiedFloatingBar', () {
    testWidgets('renders all 5 tab icons and reports taps by index', (
      tester,
    ) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFloatingBar(
              currentIndex: 0,
              onIndexSelected: (i) => selected = i,
              scrubberRow: null,
              theme: _theme,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_motion_outlined), findsOneWidget);
      expect(find.byIcon(Icons.favorite_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.palette_outlined));
      expect(selected, 3);
    });

    testWidgets('every tab is labeled and meets tap-target guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFloatingBar(
              currentIndex: 0,
              onIndexSelected: (_) {},
              scrubberRow: null,
              theme: _theme,
            ),
          ),
        ),
      );

      for (final label in [
        'Home',
        'Timeline',
        'Together',
        'Studio',
        'Settings',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets(
      'expands the scrubber row only on the timeline tab with a scrubber',
      (tester) async {
        Future<void> pump(int currentIndex, Widget? scrubberRow) {
          return tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: UnifiedFloatingBar(
                  currentIndex: currentIndex,
                  onIndexSelected: (_) {},
                  scrubberRow: scrubberRow,
                  theme: _theme,
                ),
              ),
            ),
          );
        }

        await pump(1, const Text('SCRUBBER'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).heightFactor,
          1.0,
        );

        await pump(0, const Text('SCRUBBER'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).heightFactor,
          0.0,
        );

        await pump(1, null);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).heightFactor,
          0.0,
        );
      },
    );
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'unified_floating_bar_test.dart';

void testWidgets(
  String description,
  WidgetTesterCallback callback, {
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  dynamic tags,
  int? retry,
}) {
  ft.testWidgets(description, (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'app_settings',
      jsonEncode(
        AppSettings(currentTheme: ThemeType.values.byName(_sweepTheme)).toJson(),
      ),
    );
    await callback(tester);
    final done = Completer<void>();
    runZonedGuarded(() async {
      try {
        await _evaluate(tester, description);
      } finally {
        done.complete();
      }
    }, (e, _) {
      // google_fonts can't download in tests; its failed loads surface
      // during the contrast check's real-async rendering. Anything else is
      // a genuine failure.
      if (!'$e'.contains('Failed to load font')) throw e;
    });
    await done.future;
  }, skip: skip, timeout: timeout, semanticsEnabled: semanticsEnabled, variant: variant, tags: tags);
}

Future<void> _evaluate(WidgetTester tester, String description) async {
    final handle = tester.ensureSemantics();
    await tester.pump();
    for (final g in <String, AccessibilityGuideline>{
      'tap-android': androidTapTargetGuideline,
      'tap-ios': iOSTapTargetGuideline,
      'labeled': labeledTapTargetGuideline,
      'contrast': textContrastGuideline,
    }.entries) {
      Evaluation result;
      try {
        result = await g.value.evaluate(tester);
      } catch (e) {
        result = Evaluation.fail('evaluate threw: $e');
      }
      if (!result.passed) {
        File('build/a11y_sweep.txt').writeAsStringSync(
          '${[_sweepTheme, _sweepFile, description, g.key, (result.reason ?? '').replaceAll('\n', ' | ')].join('\t')}\n',
          mode: FileMode.append,
        );
      }
    }
    handle.dispose();
}
