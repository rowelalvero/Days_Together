// Account isolation on a shared device (audit F-06/F-07, invariants S11/S12).
//
// Drives one real CoupleSession through the production auth/row handlers
// (via its @visibleForTesting seams -- the real entry points are Supabase
// streams a unit test cannot open): user A signs in and accumulates profile,
// partner PII, relationship, activity, archive and cache state; A leaves; user
// B signs in on the SAME process. Every test asserts both halves -- A's data
// is gone AND B's real server data is what the session now shows -- so none
// can pass on an empty session.
//
// Fakes stand in only where the real thing needs a platform: the push-token
// registry (Firebase), the activity log (sqflite) and sign-out (Supabase).
// The token fake models the server table: one device token, owned by
// whichever account last registered it and still holds it.

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/core/notifications/notification_service.dart';
import 'package:days_together/core/security/key_management_service.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/core/session/session_data_wiper.dart';

import 'fake_couple_service.dart';

const _deviceToken = 'device-token';

class _FakePushTokens implements PushTokenRegistry {
  _FakePushTokens(this._events);

  final List<String> _events;
  late String? Function() currentUser;

  /// token -> owning user id, i.e. the user_fcm_tokens table.
  final Map<String, String> owners = {};

  @override
  Future<void> register() async {
    final user = currentUser();
    if (user == null) return;
    owners[_deviceToken] = user;
    _events.add('register:$user');
  }

  @override
  Future<void> unregister() async {
    final user = currentUser();
    if (user != null && owners[_deviceToken] == user) {
      owners.remove(_deviceToken);
    }
    _events.add('unregister:$user');
  }
}

AuthState _signedIn(String userId) => AuthState(
  AuthChangeEvent.signedIn,
  Session(
    accessToken: 'jwt-$userId',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  ),
);

const _signedOut = AuthState(AuthChangeEvent.signedOut, null);

class _Harness {
  _Harness._(this.session, this.tokens, this.activity, this.events);

  final CoupleSession session;
  final _FakePushTokens tokens;
  final List<String> activity;
  final List<String> events;

  static Future<_Harness> create() async {
    final events = <String>[];
    final activity = <String>[];
    final tokens = _FakePushTokens(events);
    final session = CoupleSession(
      coupleService: FakeCoupleService(),
      keyManagementService: KeyManagementService.withKeyPair(
        await X25519().newKeyPair(),
      ),
      pushTokens: tokens,
      dataWiper: SessionDataWiper(
        clearActivityLog: () async => activity.clear(),
        clearImageCaches: () async {},
        clearSignedUrls: () {},
      ),
      signOut: () async => events.add('signOut'),
    );
    tokens.currentUser = () => session.userId;
    await Future.delayed(Duration.zero);
    return _Harness._(session, tokens, activity, events);
  }

  /// Signs [userId] in and delivers their server rows, as the users /
  /// couples / partner streams would.
  Future<void> signInWithServerData({
    required String userId,
    required String name,
    required String coupleId,
    required String partnerId,
    required String partnerName,
    required String startDate,
    required String storyTitle,
    Map<String, dynamic> partnerExtras = const {},
  }) async {
    await session.handleAuthChangeForTest(_signedIn(userId));
    await session.handleUserRowForTest([
      {
        'id': userId,
        'couple_id': coupleId,
        'display_name': name,
        'avatar_url': 'couples/$coupleId/avatars/$userId.jpg',
        'created_at': '2025-01-01T00:00:00Z',
      },
    ]);
    await session.handleCoupleRowForTest([
      {
        'id': coupleId,
        'partner_a_id': userId,
        'partner_b_id': partnerId,
        'status': 'active',
        'start_date': startDate,
        'story_title': storyTitle,
      },
    ]);
    await session.handlePartnerRowForTest({
      'id': partnerId,
      'display_name': partnerName,
      ...partnerExtras,
    });
  }
}

/// Signs A in with a full set of account, relationship and partner state,
/// plus the device-local stores that hang off it, and proves it all landed.
Future<_Harness> _harnessWithUserA() async {
  final h = await _Harness.create();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(PrefsKeys.appSettings, '{"theme":"rose"}');

  await h.signInWithServerData(
    userId: 'user-a',
    name: 'Alice',
    coupleId: 'couple-a',
    partnerId: 'user-p',
    partnerName: 'Pat',
    startDate: '2020-02-14T00:00:00.000Z',
    storyTitle: 'Alice & Pat',
    partnerExtras: {
      'phone': '555-0100',
      'address': '1 Secret Lane',
      'birthdate': '1990-01-01',
    },
  );
  h.activity.addAll([
    'Alice added "Paris trip"',
    'Pat changed the anniversary',
  ]);
  await prefs.setString('wrapped_archive_2025', '{"year":2025,"who":"Alice"}');
  await prefs.setString('love_chat_messages_user-a', '[{"content":"hi Pat"}]');

  // Non-vacuous precondition: A's state is really there.
  expect(h.session.yourName, 'Alice');
  expect(h.session.partnerName, 'Pat');
  expect(h.session.startDate, DateTime.utc(2020, 2, 14));
  expect(prefs.getString(PrefsKeys.partnerPhone), '555-0100');
  expect(prefs.getString(PrefsKeys.partnerAddress), '1 Secret Lane');
  expect(h.tokens.owners[_deviceToken], 'user-a');
  return h;
}

Future<void> _expectNoTraceOfA(_Harness h, {bool tokenReleased = true}) async {
  final prefs = await SharedPreferences.getInstance();
  final allValues = prefs.getKeys().map((k) => '$k=${prefs.get(k)}').join('\n');
  for (final secret in [
    'Alice',
    'Pat',
    '555-0100',
    '1 Secret Lane',
    '1990-01-01',
    '2020-02-14',
    'couple-a',
    'user-a',
  ]) {
    expect(allValues, isNot(contains(secret)), reason: 'prefs leak: $secret');
  }
  expect(prefs.getString('wrapped_archive_2025'), isNull);
  expect(prefs.getString('love_chat_messages_user-a'), isNull);
  expect(h.activity.where((a) => a.contains('Alice')), isEmpty);
  if (tokenReleased) expect(h.tokens.owners[_deviceToken], isNot('user-a'));
  // Device chrome is the one thing that survives.
  expect(prefs.getString(PrefsKeys.appSettings), '{"theme":"rose"}');
}

Future<void> _signInB(_Harness h) => h.signInWithServerData(
  userId: 'user-b',
  name: 'Bea',
  coupleId: 'couple-b',
  partnerId: 'user-q',
  partnerName: 'Quinn',
  startDate: '2023-06-01T00:00:00.000Z',
  storyTitle: 'Bea & Quinn',
);

void _expectBsServerData(_Harness h) {
  expect(h.session.userId, 'user-b');
  expect(h.session.yourName, 'Bea');
  expect(h.session.yourAvatarPath, 'couples/couple-b/avatars/user-b.jpg');
  expect(h.session.coupleId, 'couple-b');
  expect(h.session.partnerId, 'user-q');
  expect(h.session.partnerName, 'Quinn');
  expect(h.session.startDate, DateTime.utc(2023, 6, 1));
  expect(h.session.storyTitle, 'Bea & Quinn');
  expect(h.tokens.owners[_deviceToken], 'user-b');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => '.',
        );
  });

  test('A logs out, B signs in on the same process: B sees only B', () async {
    final h = await _harnessWithUserA();

    await h.session.logout();
    // logout() alone must leave no trace -- an offline sign-out may never
    // produce the signedOut event below.
    await _expectNoTraceOfA(h);
    // Supabase then emits signedOut for the sign-out logout() performed.
    await h.session.handleAuthChangeForTest(_signedOut);

    expect(h.session.userId, isNull);
    expect(h.session.yourName, isNull);
    expect(h.session.partnerName, isNull);
    expect(h.session.startDate, isNull);
    await _expectNoTraceOfA(h);

    // S12: the token was released while A was still signed in, before
    // sign-out -- not after, when the JWT is gone.
    expect(
      h.events.indexOf('unregister:user-a'),
      lessThan(h.events.indexOf('signOut')),
    );
    expect(h.tokens.owners, isEmpty);

    await _signInB(h);
    h.activity.add('Bea added "Kyoto"');

    _expectBsServerData(h);
    await _expectNoTraceOfA(h);
    expect(h.activity, ['Bea added "Kyoto"']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefsKeys.yourName), 'Bea');
    expect(prefs.getString(PrefsKeys.partnerName), 'Quinn');
    expect(prefs.getString(PrefsKeys.userId), 'user-b');
  });

  test(
    'session revoked server-side (no logout): the signed-out event wipes A',
    () async {
      final h = await _harnessWithUserA();

      await h.session.handleAuthChangeForTest(_signedOut);

      expect(h.session.userId, isNull);
      expect(h.session.yourName, isNull);
      // Known residual: with the JWT already gone, the device cannot delete
      // its own token row, so it stays A's until the next account takes it
      // over (upsert_user_fcm_token reassigns a token to the new caller).
      await _expectNoTraceOfA(h, tokenReleased: false);
      expect(h.tokens.owners[_deviceToken], 'user-a');

      await _signInB(h);
      _expectBsServerData(h);
      await _expectNoTraceOfA(h);
    },
  );

  test(
    'account switch with no sign-out event at all: B signing in wipes A first',
    () async {
      final h = await _harnessWithUserA();

      await _signInB(h);

      _expectBsServerData(h);
      await _expectNoTraceOfA(h);
    },
  );

  test(
    'a user who never paired does not inherit the previous account\'s name',
    () async {
      final h = await _harnessWithUserA();
      await h.session.logout();
      await h.session.handleAuthChangeForTest(_signedOut);

      // B has no display name on the server yet and no couple. This is the
      // exact path that used to fall back to A's cached name and start date.
      await h.session.handleAuthChangeForTest(_signedIn('user-b'));
      await h.session.handleUserRowForTest([
        {'id': 'user-b', 'couple_id': null, 'display_name': null},
      ]);

      expect(h.session.userId, 'user-b');
      expect(h.session.yourName, isNull);
      expect(h.session.startDate, isNull);
      expect(h.session.onboardingCompleted, isFalse);
      expect(h.tokens.owners[_deviceToken], 'user-b');
      await _expectNoTraceOfA(h);
    },
  );

  test(
    'unlink drops the relationship and partner PII but keeps A\'s own account',
    () async {
      final h = await _harnessWithUserA();

      await h.session.unlinkPartner();

      final prefs = await SharedPreferences.getInstance();
      // Couple scope: gone.
      expect(h.session.coupleId, isNull);
      expect(h.session.partnerName, isNull);
      expect(h.session.startDate, isNull);
      expect(h.session.storyTitle, 'Our Story'); // the getter's default
      expect(prefs.getString(PrefsKeys.partnerPhone), isNull);
      expect(prefs.getString(PrefsKeys.partnerAddress), isNull);
      expect(prefs.getString(PrefsKeys.relationshipStartDate), isNull);
      expect(prefs.getString('wrapped_archive_2025'), isNull);
      expect(prefs.getString('love_chat_messages_user-a'), isNull);
      expect(h.activity, isEmpty);
      // User scope: kept -- A is still signed in as A.
      expect(h.session.userId, 'user-a');
      expect(h.session.yourName, 'Alice');
      expect(prefs.getString(PrefsKeys.yourName), 'Alice');
      expect(prefs.getString(PrefsKeys.userId), 'user-a');
      expect(h.tokens.owners[_deviceToken], 'user-a');
      expect(prefs.getString(PrefsKeys.appSettings), '{"theme":"rose"}');
    },
  );
}
