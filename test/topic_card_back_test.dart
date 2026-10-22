// Widget tests for TopicCardBack's action buttons: each is labeled for
// screen readers and keeps a 48dp tap target. The custom-card delete button
// used to be shrunk to its 20px icon (BoxConstraints() + EdgeInsets.zero).
// The controller is a real, unpaired TopicCardsController -- nothing here
// is tapped, so nothing reaches Supabase.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/topic_cards/domain/entities/topic_card_model.dart';
import 'package:days_together/features/topic_cards/presentation/widgets/topic_card_back.dart';
import 'package:days_together/features/topic_cards/topic_cards_controller.dart';

final _theme = ThemeManager.themes.values.first;

Future<void> _pump(WidgetTester tester, TopicCard card) async {
  final container = ProviderContainer(
    overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
  );
  addTearDown(container.dispose);
  container.listen(topicCardsControllerProvider, (prev, next) {});

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: TopicCardBack(
              theme: _theme,
              card: card,
              notifier: container.read(topicCardsControllerProvider.notifier),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'user_id': 'u1'}));

  testWidgets(
    'custom card: delete, share and favorite are labeled 48dp targets',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        TopicCard(
          id: 'c1',
          category: 'Fun & Quirky',
          question: 'Our own question?',
          isCustom: true,
        ),
      );

      expect(find.byTooltip('Delete card'), findsOneWidget);
      expect(find.byTooltip('Share topic'), findsOneWidget);
      expect(find.byTooltip('Add to favorites'), findsOneWidget);

      final delete = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.delete_outline_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(delete.width, greaterThanOrEqualTo(48));
      expect(delete.height, greaterThanOrEqualTo(48));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );

  testWidgets(
    'built-in card has no delete button; liked card offers unfavorite',
    (tester) async {
      await _pump(
        tester,
        TopicCard(
          id: 'd1',
          category: 'Deep Talk',
          question: 'A built-in question?',
          isLiked: true,
        ),
      );

      expect(find.byTooltip('Delete card'), findsNothing);
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);
      expect(find.text('A built-in question?'), findsOneWidget);
    },
  );
}
