// Screen-reader navigation for the Wrapped story. The sighted tap zones are
// invisible full-screen GestureDetectors, which a screen reader can't use;
// these tests pin the replacement: the progress bar is a "Page n of N" live
// region carrying Next/Previous custom actions, the tap zones stay out of
// the semantics tree, and Skip is a labeled 48dp button.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart' as ft show testWidgets;
import 'dart:async' show Completer, runZonedGuarded;
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import 'package:days_together/shared/models/app_settings.dart' show AppSettings, ThemeType;

import 'package:days_together/features/wrapped/presentation/widgets/wrapped_nav_overlay.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_progress_bar.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: Colors.black, body: child),
);

void main() {
  group('WrappedProgressBar', () {
    testWidgets('announces the page and exposes Next/Previous actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var next = 0, previous = 0;
      await tester.pumpWidget(
        _host(
          WrappedProgressBar(
            totalPages: 14,
            currentPage: 2,
            onNext: () => next++,
            onPrevious: () => previous++,
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(WrappedProgressBar));
      expect(
        node,
        matchesSemantics(
          label: 'Page 3 of 14',
          isLiveRegion: true,
          customActions: const [
            WrappedProgressBar.nextPageAction,
            WrappedProgressBar.previousPageAction,
          ],
        ),
      );

      // Dispatch each action the way the platform's screen reader does.
      final owner = tester
          .renderObject(find.byType(WrappedProgressBar))
          .owner!
          .semanticsOwner!;
      for (final action in [
        WrappedProgressBar.nextPageAction,
        WrappedProgressBar.previousPageAction,
      ]) {
        owner.performAction(
          node.id,
          SemanticsAction.customAction,
          CustomSemanticsAction.getIdentifier(action),
        );
      }
      expect(next, 1);
      expect(previous, 1);
      handle.dispose();
    });

    testWidgets(
      'offers no Previous on the first page and no Next on the last',
      (tester) async {
        final handle = tester.ensureSemantics();
        Future<Set<String>> actionsAt(int page) async {
          await tester.pumpWidget(
            _host(
              WrappedProgressBar(
                totalPages: 14,
                currentPage: page,
                onNext: () {},
                onPrevious: () {},
              ),
            ),
          );
          final data = tester
              .getSemantics(find.byType(WrappedProgressBar))
              .getSemanticsData();
          return {
            for (final id in data.customSemanticsActionIds ?? <int>[])
              CustomSemanticsAction.getAction(id)!.label!,
          };
        }

        expect(await actionsAt(0), {'Next page'});
        expect(await actionsAt(6), {'Next page', 'Previous page'});
        expect(await actionsAt(13), {'Previous page'});
        handle.dispose();
      },
    );
  });

  group('WrappedNavOverlay', () {
    testWidgets('tap zones still page for pointer users', (tester) async {
      var next = 0, previous = 0;
      await tester.pumpWidget(
        _host(
          WrappedNavOverlay(
            onNext: () => next++,
            onPrevious: () => previous++,
            onSkip: () {},
          ),
        ),
      );
      final size = tester.getSize(find.byType(WrappedNavOverlay));
      await tester.tapAt(Offset(size.width * 0.1, size.height / 2));
      await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
      expect(previous, 1);
      expect(next, 1);
    });

    testWidgets('only Skip is exposed to screen readers, as a 48dp button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var skipped = false;
      await tester.pumpWidget(
        _host(
          WrappedNavOverlay(
            onNext: () {},
            onPrevious: () {},
            onSkip: () => skipped = true,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Skip')),
        matchesSemantics(label: 'Skip', isButton: true, hasTapAction: true),
      );
      // The two screen-sized tap zones contribute no tappable nodes.
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      await tester.tap(find.text('Skip'));
      expect(skipped, isTrue);
      handle.dispose();
    });

    testWidgets('Skip is hidden on the last page', (tester) async {
      await tester.pumpWidget(
        _host(
          WrappedNavOverlay(
            onNext: () {},
            onPrevious: () {},
            onSkip: () {},
            isLastPage: true,
          ),
        ),
      );
      expect(find.text('Skip'), findsNothing);
      expect(find.byType(WrappedNavOverlay), findsOneWidget);
    });
  });
}

// ---- a11y sweep harness (generated) ----
const _sweepTheme = String.fromEnvironment('SWEEP_THEME', defaultValue: 'offWhite');
const _sweepFile = 'wrapped_navigation_semantics_test.dart';

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
