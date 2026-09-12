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
import 'package:flutter_test/flutter_test.dart';

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
