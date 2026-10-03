// Widget tests for the paging UI: the shared PagedListFooter states, the
// memory route a tapped notification opens (which must load a memory that
// is outside the timeline's page window), and the love-letter memory
// picker's scroll-to-load.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/models/paging_status.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/love_studio/presentation/widgets/memory_picker.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/timeline/presentation/pages/memory_detail_screen.dart';
import 'package:days_together/features/timeline/presentation/pages/memory_route_screen.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/timeline/timeline_state.dart';
import 'package:days_together/shared/models/timeline_model.dart';
import 'package:days_together/shared/widgets/paged_list_footer.dart';

TimelineItemData _memory(int n) => TimelineItemData(
  id: 'm$n',
  title: 'Memory $n',
  description: '',
  date: DateTime(2024, 1, n),
  isImageCard: false,
  position: n,
);

/// A timeline whose server is a [Completer] the test resolves.
class _ScriptedTimeline extends TimelineController {
  _ScriptedTimeline(this._seed);
  final TimelineState _seed;
  Completer<TimelineItemData?> lookup = Completer();
  int lookups = 0;
  int loadMoreCalls = 0;

  @override
  TimelineState build() => _seed;

  @override
  Future<TimelineItemData?> loadMemory(String id) async {
    lookups++;
    final item = await lookup.future;
    if (item != null) {
      state = state.copyWith(detached: {...state.detached, item.id: item});
    }
    return item;
  }

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
  }
}

Widget _app(Widget child, _ScriptedTimeline timeline) => ProviderScope(
  overrides: [
    coupleSessionProvider.overrideWithValue(CoupleSession()),
    timelineControllerProvider.overrideWith(() => timeline),
  ],
  child: MaterialApp(home: child),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PagedListFooter', () {
    Future<void> pump(WidgetTester tester, PagingStatus status) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PagedListFooter(
                status: status,
                onRetry: () {},
                color: Colors.black,
                endLabel: 'The end',
              ),
            ),
          ),
        );

    testWidgets('shows a spinner while a page loads', (tester) async {
      await pump(
        tester,
        const PagingStatus(hasMore: true, isLoadingMore: true),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('offers a retry after a failure', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PagedListFooter(
              status: const PagingStatus(hasMore: true, loadMoreFailed: true),
              onRetry: () => retried++,
              color: Colors.black,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('says so at the end of the list', (tester) async {
      await pump(tester, const PagingStatus());
      expect(find.text('The end'), findsOneWidget);
    });

    testWidgets('is empty while more is available but not loading', (
      tester,
    ) async {
      await pump(tester, const PagingStatus(hasMore: true));
      expect(find.text('The end'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(PagedListFooter), findsOneWidget);
    });
  });

  group('MemoryRouteScreen (a tapped notification)', () {
    Future<void> pumpRoute(WidgetTester tester, _ScriptedTimeline t) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const MemoryRouteScreen(itemId: 'm7'), t));
    }

    testWidgets('opens a loaded memory straight away', (tester) async {
      final t = _ScriptedTimeline(TimelineState(items: [_memory(7)]));
      await pumpRoute(tester, t);
      await tester.pumpAndSettle();
      expect(find.byType(MemoryDetailScreen), findsOneWidget);
      expect(t.lookups, 0);
    });

    testWidgets('loads a memory outside the window, then opens it', (
      tester,
    ) async {
      final t = _ScriptedTimeline(TimelineState(items: [_memory(1)]));
      await pumpRoute(tester, t);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(MemoryDetailScreen), findsNothing);

      t.lookup.complete(_memory(7));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryDetailScreen), findsOneWidget);
      expect(find.text('Memory 7'), findsWidgets);
      expect(t.lookups, 1);
    });

    testWidgets('says when the memory no longer exists', (tester) async {
      final t = _ScriptedTimeline(const TimelineState());
      await pumpRoute(tester, t);
      t.lookup.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('This memory no longer exists.'), findsOneWidget);
      expect(find.byType(MemoryDetailScreen), findsNothing);
    });

    testWidgets('offers a retry when loading fails', (tester) async {
      final t = _ScriptedTimeline(const TimelineState());
      await pumpRoute(tester, t);
      t.lookup.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load this memory."), findsOneWidget);

      t.lookup = Completer()..complete(_memory(7));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryDetailScreen), findsOneWidget);
      expect(t.lookups, 2);
    });
  });

  group('MemoryPickerSheet', () {
    testWidgets('scrolling near the end loads the next page; a failed page '
        'stops it', (tester) async {
      final memories = [for (var i = 1; i <= 30; i++) _memory(i)];
      Future<void> pumpSheet(_ScriptedTimeline t) => tester.pumpWidget(
        _app(
          Consumer(
            builder: (context, ref, _) => Scaffold(
              body: MemoryPickerSheet(
                selectedId: null,
                theme: ref.watch(themeControllerProvider).currentLoveTheme,
              ),
            ),
          ),
          t,
        ),
      );

      final t = _ScriptedTimeline(
        TimelineState(
          items: memories,
          paging: const PagingStatus(hasMore: true),
        ),
      );
      await pumpSheet(t);
      await tester.pumpAndSettle();
      expect(t.loadMoreCalls, 0);
      await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
      await tester.pumpAndSettle();
      expect(t.loadMoreCalls, greaterThan(0));

      final failed = _ScriptedTimeline(
        TimelineState(
          items: memories,
          paging: const PagingStatus(hasMore: true, loadMoreFailed: true),
        ),
      );
      // A fresh ProviderScope, not an update of the first one.
      await tester.pumpWidget(const SizedBox());
      await pumpSheet(failed);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
      await tester.pumpAndSettle();
      expect(failed.loadMoreCalls, 0);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
