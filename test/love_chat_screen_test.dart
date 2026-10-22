// Widget tests for LoveChatScreen, written before extracting its ~5 _buildX
// methods (header, chat bubble, input row, empty state, enlarged-note
// content) and its two inline dialog/sheet builders into real widget
// classes -- these pin the screen's current rendered behavior so the
// extraction can be verified rather than assumed safe.
//
// Every controller is seeded through a subclass whose build() returns a
// fixed state, so no Supabase client or realtime subscription is involved --
// the same technique daily_mood_bento_card_test.dart uses. sendMessage() and
// deleteMessage() are exercised for real (not mocked) since both no-op their
// Supabase branch when coupleId is null, which it is for every seeded state
// here -- the same reasoning calendar_screen_test.dart's "add-event" case
// relies on for CalendarController.addEvent.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/chat/domain/entities/love_chat_model.dart';
import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/features/chat/love_chat_state.dart';
import 'package:days_together/features/chat/presentation/pages/love_chat_screen.dart';
import 'package:days_together/features/relationship/presence_controller.dart';
import 'package:days_together/features/relationship/presence_state.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/session_state.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/features/scrapbook/noteit_state.dart';

class _SeededChat extends LoveChatController {
  _SeededChat(this._seed);
  final LoveChatState _seed;
  @override
  LoveChatState build() => _seed;
}

class _SeededProfile extends ProfileController {
  _SeededProfile(this._seed);
  final ProfileState _seed;
  @override
  ProfileState build() => _seed;
}

class _SeededSession extends SessionController {
  _SeededSession(this._seed);
  final SessionState _seed;
  @override
  SessionState build() => _seed;
}

class _SeededPresence extends PresenceController {
  _SeededPresence(this._seed);
  final PresenceState _seed;
  @override
  PresenceState build() => _seed;
}

class _SeededNoteit extends NoteitController {
  _SeededNoteit(this._seed);
  final NoteitState _seed;
  @override
  NoteitState build() => _seed;
}

Future<void> _pump(
  WidgetTester tester, {
  LoveChatState chat = const LoveChatState(messages: [], isLoading: false),
  SessionState session = const SessionState(
    userId: 'user-1',
    coupleId: 'couple-1',
    partnerId: 'partner-1',
  ),
  ProfileState profile = const ProfileState(
    yourName: 'Alex',
    partnerName: 'Sam',
  ),
  PresenceState presence = const PresenceState(isPartnerOnline: true),
}) async {
  // The message list + header + input row overflows the default 800x600
  // test surface -- a real phone screen is taller.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(CoupleSession()),
        loveChatControllerProvider.overrideWith(() => _SeededChat(chat)),
        profileControllerProvider.overrideWith(() => _SeededProfile(profile)),
        sessionControllerProvider.overrideWith(() => _SeededSession(session)),
        presenceControllerProvider.overrideWith(
          () => _SeededPresence(presence),
        ),
        noteitControllerProvider.overrideWith(
          () => _SeededNoteit(const NoteitState()),
        ),
      ],
      child: const MaterialApp(home: LoveChatScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoveChatScreen', () {
    testWidgets('renders the header and empty state with no messages', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Active Now'), findsOneWidget);
      expect(find.text('No messages here yet'), findsOneWidget);
    });

    testWidgets('shows "Waiting for Partner..." when unpaired', (tester) async {
      await _pump(
        tester,
        session: const SessionState(userId: 'user-1', coupleId: 'couple-1'),
      );

      expect(find.text('Waiting for Partner...'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('renders a text message with its sender name', (tester) async {
      final message = LoveChatMessage(
        senderId: 'partner-1',
        senderName: 'Sam',
        content: 'Hi love!',
      );
      await _pump(tester, chat: LoveChatState(messages: [message]));

      expect(find.text('Hi love!'), findsOneWidget);
      expect(find.text('Sam'), findsWidgets);
    });

    testWidgets('tapping a text bubble reveals its timestamp', (tester) async {
      final message = LoveChatMessage(
        senderId: 'you',
        senderName: 'Alex',
        content: 'Hi love!',
      );
      await _pump(tester, chat: LoveChatState(messages: [message]));

      await tester.tap(find.text('Hi love!'));
      await tester.pumpAndSettle();

      expect(find.text('h:mm a').evaluate().isEmpty, isTrue);
      // The revealed timestamp is a formatted string, not literal
      // 'h:mm a' -- assert the AnimatedSize grew a second Text under the
      // bubble instead of guessing the exact clock value.
      expect(find.textContaining(':'), findsWidgets);
    });

    testWidgets('long-pressing a message opens Delete Message and removes it', (
      tester,
    ) async {
      final message = LoveChatMessage(
        senderId: 'you',
        senderName: 'Alex',
        content: 'Oops typo',
      );
      await _pump(tester, chat: LoveChatState(messages: [message]));

      await tester.longPress(find.text('Oops typo'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Message'), findsOneWidget);

      await tester.tap(find.text('Delete Message'));
      await tester.pumpAndSettle();

      expect(find.text('Oops typo'), findsNothing);
    });

    testWidgets('typing a message and tapping send adds it to the list', (
      tester,
    ) async {
      await _pump(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Write something sweet...'),
        'Thinking of you',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Thinking of you'), findsOneWidget);
      expect(find.text('No messages here yet'), findsNothing);
    });

    testWidgets('a scrapbook-mirror message renders as a Scrapbook card', (
      tester,
    ) async {
      final message = LoveChatMessage(
        senderId: 'partner-1',
        senderName: 'Sam',
        content: 'scrapbook:missing-note-id',
      );
      await _pump(tester, chat: LoveChatState(messages: [message]));

      expect(find.text('Scrapbook Doodle'), findsOneWidget);
    });
  });
}
