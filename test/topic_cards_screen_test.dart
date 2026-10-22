// Widget tests for TopicCardsScreen, written before extracting its ~15
// _buildX methods into real widget classes -- these pin the screen's current
// rendered behavior so the extraction can be verified rather than assumed
// safe.
//
// The controller is seeded through a subclass whose build() returns a fixed
// state, so no Supabase client or realtime subscription is involved -- the
// same technique daily_mood_bento_card_test.dart uses.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/topic_cards/presentation/pages/topic_cards_screen.dart';
import 'package:days_together/features/topic_cards/topic_cards_controller.dart';
import 'package:days_together/features/topic_cards/topic_cards_state.dart';

class _SeededTopicCards extends TopicCardsController {
  _SeededTopicCards(this._seed);
  final TopicCardsState _seed;
  @override
  TopicCardsState build() => _seed;
}

Future<void> _pump(WidgetTester tester, TopicCardsState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(CoupleSession()),
        topicCardsControllerProvider.overrideWith(
          () => _SeededTopicCards(state),
        ),
      ],
      child: const MaterialApp(home: TopicCardsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TopicCardsScreen', () {
    testWidgets('renders the deck, category tabs, and controls when the '
        'deck is non-empty', (tester) async {
      await _pump(tester, const TopicCardsState(isLoading: false));

      expect(find.text('Topic Cards'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Deep Conversations'), findsOneWidget);

      // The card front, face up by default.
      expect(find.text('Conversation Deck'), findsOneWidget);
      expect(find.text('TAP TO REVEAL'), findsOneWidget);

      // Previous / shuffle / next controls.
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });

    testWidgets('tapping the card flips it to reveal the question', (
      tester,
    ) async {
      await _pump(tester, const TopicCardsState(isLoading: false));

      final firstQuestion = TopicCardsState.defaultCards.first.question;
      expect(find.text(firstQuestion), findsNothing);

      await tester.tap(find.text('Conversation Deck'));
      await tester.pumpAndSettle();

      expect(find.text(firstQuestion), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    });

    testWidgets('shows the Favorites empty state when nothing is liked', (
      tester,
    ) async {
      await _pump(
        tester,
        const TopicCardsState(isLoading: false, activeCategory: 'Favorites'),
      );

      expect(find.text('No Favorited Topics'), findsOneWidget);
      expect(
        find.text('Create Custom Card'),
        findsNothing,
        reason:
            'Favorites has no "add a card" action -- there is no '
            'category to add it to',
      );
    });

    testWidgets(
      'the add-card sheet validates, submits, and adds the card to the deck',
      (tester) async {
        await _pump(
          tester,
          const TopicCardsState(isLoading: false, activeCategory: 'Favorites'),
        );

        // Favorites' empty state has no create button; switch category via
        // the app bar action instead, which is always present.
        await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Create Custom Card'), findsOneWidget);

        // Submitting blank is rejected by the form validator.
        await tester.tap(find.text('Add to Deck'));
        await tester.pumpAndSettle();
        expect(find.text('Please share a question or prompt.'), findsOneWidget);

        await tester.enterText(
          find.byType(TextFormField),
          'What made you smile today?',
        );
        await tester.tap(find.text('Add to Deck'));
        await tester.pumpAndSettle();

        expect(find.text('Create Custom Card'), findsNothing);
        expect(
          find.text('Custom prompt added to your deck! 🃏'),
          findsOneWidget,
        );
      },
    );
  });
}
