// Widget tests for BucketListScreen, written before extracting its ~5
// _buildX methods and its inline `_showAddItemSheet`
// (showModalBottomSheet + StatefulBuilder closure) into real widget
// classes -- these pin the screen's current rendered behavior so the
// extraction can be verified rather than assumed safe.
//
// BucketListController is seeded through a subclass whose build() returns a
// fixed state, so no Supabase client or realtime subscription is involved --
// the same technique calendar_screen_test.dart uses. addItem/updateItem/
// deleteItem/toggleItem are exercised for real (not mocked) since they all
// no-op their Supabase branch when coupleId is null, which it is for every
// seeded state here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/features/bucket_list/bucket_list_state.dart';
import 'package:days_together/features/bucket_list/domain/entities/bucket_list_model.dart';
import 'package:days_together/features/bucket_list/presentation/pages/bucket_list_screen.dart';

class _SeededBucketList extends BucketListController {
  _SeededBucketList(this._seed);
  final BucketListState _seed;
  @override
  BucketListState build() => _seed;
}

Future<void> _pump(
  WidgetTester tester, {
  BucketListState bucketList = const BucketListState(
    items: [],
    isLoading: false,
  ),
}) async {
  // The progress card + reorderable list overflow the default 800x600 test
  // surface -- a real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(CoupleSession()),
        bucketListControllerProvider.overrideWith(
          () => _SeededBucketList(bucketList),
        ),
      ],
      child: const MaterialApp(home: BucketListScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BucketListScreen', () {
    testWidgets('shows the empty state with no items', (tester) async {
      await _pump(tester);

      expect(find.text('Dream big.'), findsOneWidget);
      expect(find.text('Add your first adventure together.'), findsOneWidget);
    });

    testWidgets('renders the progress card and item tiles', (tester) async {
      await _pump(
        tester,
        bucketList: BucketListState(
          isLoading: false,
          items: [
            BucketListItem(title: 'Watch the sunset', order: 0),
            BucketListItem(title: 'Visit Japan', order: 1, isCompleted: true),
          ],
        ),
      );

      expect(find.text('1 of 2 adventures completed'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Watch the sunset'), findsOneWidget);
      expect(find.text('Visit Japan'), findsOneWidget);
    });

    testWidgets('adding a new adventure shows it in the list', (tester) async {
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('✨ Add New Adventure'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Watch the sunset in Santorini 🌅'),
        'Road trip along the coast',
      );
      await tester.tap(find.text('Add to List'));
      await tester.pumpAndSettle();

      expect(find.text('✨ Add New Adventure'), findsNothing);
      expect(find.text('Road trip along the coast'), findsOneWidget);
    });

    testWidgets(
      'tapping the edit icon opens a pre-filled sheet, and saving closes it',
      (tester) async {
        // NOTE: BucketListController.updateItem's local-state write is
        // nested inside its `coupleId != null` branch (a pre-existing bug,
        // not touched by this refactor), so an unpaired save like this one
        // does not actually change the displayed title -- this test only
        // pins the sheet's open/pre-fill/close behavior, not that outcome.
        await _pump(
          tester,
          bucketList: BucketListState(
            isLoading: false,
            items: [BucketListItem(title: 'Watch the sunset', order: 0)],
          ),
        );

        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        expect(find.text('📝 Edit Adventure'), findsOneWidget);
        expect(
          find.widgetWithText(TextField, 'Watch the sunset'),
          findsOneWidget,
        );

        await tester.tap(find.text('Update Adventure'));
        await tester.pumpAndSettle();

        expect(find.text('📝 Edit Adventure'), findsNothing);
      },
    );

    testWidgets('toggling an item marks it completed', (tester) async {
      await _pump(
        tester,
        bucketList: BucketListState(
          isLoading: false,
          items: [
            BucketListItem(id: 'item-1', title: 'Watch the sunset', order: 0),
          ],
        ),
      );

      expect(find.byIcon(Icons.favorite), findsNothing);

      // Completing an item plays the confetti animation, which never
      // settles -- pump a couple of frames instead of pumpAndSettle.
      await tester.tap(find.byKey(const ValueKey('bucket-item-toggle-item-1')));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('deleting an adventure confirms, then removes it', (
      tester,
    ) async {
      await _pump(
        tester,
        bucketList: BucketListState(
          isLoading: false,
          items: [BucketListItem(title: 'Watch the sunset', order: 0)],
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Delete Adventure?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Watch the sunset'), findsNothing);
      expect(find.text('Dream big.'), findsOneWidget);
    });
  });
}
