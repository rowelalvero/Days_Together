// PartnerKeySecurityCard (re-audit R-03): shows the couple's safety number,
// and on a partner key change shows the warning plus the explicit
// confirmation that resumes photo-key sharing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/shared/models/app_settings.dart';
import 'package:days_together/features/relationship/presentation/profile/components/partner_key_security_card.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/session_state.dart';

const _number = '12345 67890 13579 24680 11223 34455';

class _FakeSession extends CoupleSession {
  int accepted = 0;

  @override
  Future<String?> loadSafetyNumber() async => _number;

  @override
  Future<void> acceptPartnerKeyChange() async => accepted++;
}

class _SeededSession extends SessionController {
  _SeededSession(this._seed);
  final SessionState _seed;
  @override
  SessionState build() => _seed;
}

Future<_FakeSession> _pump(WidgetTester tester, {required bool changed}) async {
  final session = _FakeSession();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleSessionProvider.overrideWithValue(session),
        sessionControllerProvider.overrideWith(
          () => _SeededSession(
            SessionState(partnerId: 'partner', partnerKeyChanged: changed),
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PartnerKeySecurityCard(
              theme: ThemeManager.getTheme(ThemeType.midnightRose),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('normal state: safety number, no confirmation button', (
    tester,
  ) async {
    await _pump(tester, changed: false);

    expect(find.text('Encryption safety number'), findsOneWidget);
    expect(find.text(_number), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('key changed: warning, number to compare, and explicit accept', (
    tester,
  ) async {
    final session = await _pump(tester, changed: true);

    expect(find.text('Your partner\'s security key changed'), findsOneWidget);
    expect(find.text(_number), findsOneWidget);
    expect(session.accepted, 0, reason: 'never accepted implicitly');

    await tester.tap(find.text('Numbers match -- trust the new key'));
    await tester.pumpAndSettle();

    expect(session.accepted, 1);
  });
}
