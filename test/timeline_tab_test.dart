// Widget tests for TimelineTab, written before extracting its
// `_buildEmptyState` method into a real widget class -- these pin the
// screen's current rendered behavior so the extraction can be verified
// rather than assumed safe. The rest of the tab (list/storybook mode
// switching, scrub-index sync) is genuine interaction/state logic, not
// _buildX sprawl, so it stays on the tab's State.
//
// TimelineController and WorkspaceController are seeded through
// subclasses whose build() returns a fixed state (the same technique
// license_screen_test.dart uses). WorkspaceController.setStoryTitle
// delegates straight to CoupleSession, whose own Riverpod state isn't
// wired to rebuild in this isolated widget test, so that write is
// asserted against the shared CoupleSession instance directly (same
// pattern as settings_tab_test.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/features/timeline/presentation/pages/timeline_tab.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/timeline/timeline_state.dart';
import 'package:days_together/shared/models/timeline_model.dart';

class _SeededTimeline extends TimelineController {
  _SeededTimeline(this._seed);
  final TimelineState _seed;
  @override
  TimelineState build() => _seed;
}

class _SeededWorkspace extends WorkspaceController {
  _SeededWorkspace(this._seed);
  final WorkspaceState _seed;
  @override
  WorkspaceState build() => _seed;
}

final _memoryOne = TimelineItemData(
  id: 'memory-1',
  title: 'Beach Day',
  description: 'We watched the sunset together.',
  date: DateTime(2024, 6, 15),
  isImageCard: false,
  position: 0,
  mood: '😍',
);

Future<void> _pump(
  WidgetTester tester, {
  required List<TimelineItemData> items,
  CoupleSession? session,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (session != null) coupleSessionProvider.overrideWithValue(session),
        timelineControllerProvider.overrideWith(
          () => _SeededTimeline(TimelineState(items: items, isLoading: false)),
        ),
        workspaceControllerProvider.overrideWith(
          () => _SeededWorkspace(const WorkspaceState(storyTitle: 'Our Story')),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: TimelineTab())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TimelineTab', () {
    testWidgets(
      'shows the empty state and no FAB row when there are no items',
      (tester) async {
        await _pump(tester, items: []);

        expect(find.text('Your story begins here.'), findsOneWidget);
        expect(find.text('Capture first memory'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
        expect(find.byIcon(Icons.auto_stories_rounded), findsNothing);
      },
    );

    testWidgets('renders items and the sort/storybook FAB row', (tester) async {
      await _pump(tester, items: [_memoryOne]);

      expect(find.text('Our Story'), findsOneWidget);
      expect(find.text('Beach Day'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    });

    testWidgets('the sort toggle flips the ascending/descending icon', (
      tester,
    ) async {
      await _pump(tester, items: [_memoryOne]);

      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('the storybook toggle switches into storybook mode', (
      tester,
    ) async {
      await _pump(tester, items: [_memoryOne]);

      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.auto_stories_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.auto_awesome_motion_rounded), findsOneWidget);
    });

    testWidgets('editing the story title writes through to CoupleSession', (
      tester,
    ) async {
      final session = CoupleSession();
      await _pump(tester, items: [_memoryOne], session: session);

      await tester.tap(find.text('Our Story'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Our New Story');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(session.storyTitle, 'Our New Story');
    });
  });
}
