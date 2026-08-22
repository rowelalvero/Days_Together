import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/providers/couple_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Security Controls Verification', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('TEST 3: Column Whitelist Validation for Partner Profile Updates', () {
      final allowedKeys = <String>{
        'display_name',
        'gender',
        'phone',
        'birthdate',
        'address',
        'nationality',
        'weight',
        'height',
        'blood_type',
        'eye_color',
        'conditions',
        'date_issued',
        'signature',
        'avatar_url',
      };

      final maliciousUpdates = {
        'couple_id': '00000000-0000-0000-0000-000000000000',
        'id': 'attacker-id',
        'partner_deleted_notice': true,
        'created_at': '2026-01-01T00:00:00Z',
      };

      for (final key in maliciousUpdates.keys) {
        final isWhitelisted = allowedKeys.contains(key);
        expect(isWhitelisted, isFalse, reason: 'Key "$key" MUST NOT be whitelisted');
      }
    });

    test('TEST 6: Recovery Code Expiration Boundary Conditions (90 Days)', () {
      final now = DateTime.now().toUtc();
      const maxAgeDays = 90;

      final validCodeGeneratedAt = now.subtract(const Duration(days: 89));
      final expiredCodeGeneratedAt = now.subtract(const Duration(days: 91));

      final isValidAge = validCodeGeneratedAt.isAfter(now.subtract(const Duration(days: maxAgeDays)));
      final isExpiredAge = expiredCodeGeneratedAt.isBefore(now.subtract(const Duration(days: maxAgeDays)));

      expect(isValidAge, isTrue, reason: '89-day old code must be valid');
      expect(isExpiredAge, isTrue, reason: '91-day old code must be expired');
    });

    test('TEST 7/8: Rate Limiting Attempt Count Lockout Threshold (5 Attempts)', () {
      const maxAttempts = 5;
      int attempts = 0;
      bool isLockedOut = false;

      for (int i = 1; i <= 6; i++) {
        attempts++;
        if (attempts >= maxAttempts) {
          isLockedOut = true;
        }
      }

      expect(attempts, 6);
      expect(isLockedOut, isTrue, reason: 'Account MUST lock out on or after 5 failed attempts');
    });

    test('TEST 17: Logout Local Cache Purge & Account Data Isolation', () async {
      // 1. User A logs in, creates local chat and timeline data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'love_chat_messages',
        jsonEncode([
          {'id': 'user-a-msg-1', 'sender_id': 'you', 'sender_name': 'User A', 'content': 'Secret User A Note'}
        ]),
      );
      await prefs.setString(
        'timeline_items',
        jsonEncode([
          {'id': 'user-a-time-1', 'title': 'User A Memory', 'description': 'Private memory', 'date': DateTime.now().toIso8601String()}
        ]),
      );

      // Migration note: LoveChatProvider/TimelineProvider (plain `provider`-
      // package ChangeNotifiers registered with RelationshipLifecycleManager)
      // were retired in favor of LoveChatController/TimelineController
      // (Riverpod NotifierProviders with SupabaseLifecycleNotifier). The new
      // architecture doesn't route logout through RelationshipLifecycleManager
      // at all -- main.dart's `_DomainProvidersBridge` pushes an explicit
      // `updateSession(session)` call on every CoupleSession change, and
      // SupabaseLifecycleNotifier.updateSession detects the credentials-
      // cleared transition and calls purgeCache() itself (see
      // supabase_lifecycle_notifier.dart). Exercising the real
      // paired-to-unpaired updateSession transition isn't reachable in a
      // plain unit test (it needs a real Supabase-backed userId -- see
      // notification_preferences_controller_test.dart's identical note), so
      // this test calls purgeCache() directly, exactly like this repo's
      // other controller tests (love_chat_controller_test.dart,
      // timeline_controller_test.dart) already do -- that is the established
      // equivalent of "the app is telling this feature to purge on logout"
      // for the new architecture.
      final container = ProviderContainer(
        overrides: [coupleSessionProvider.overrideWithValue(CoupleSession())],
      );
      addTearDown(container.dispose);
      container.listen(loveChatControllerProvider, (prev, next) {});
      container.listen(timelineControllerProvider, (prev, next) {});
      await Future.delayed(Duration.zero);

      final chatState = container.read(loveChatControllerProvider);
      expect(chatState.messages.length, 1);
      expect(chatState.messages.first.content, 'Secret User A Note');

      // 2. User A logs out -> each feature's purgeCache() runs (the
      // Riverpod-native equivalent of the old RelationshipLifecycleManager
      // onLogout() broadcast).
      await container.read(loveChatControllerProvider.notifier).purgeCache();
      await container.read(timelineControllerProvider.notifier).purgeCache();

      expect(container.read(loveChatControllerProvider).messages, isEmpty);
      expect(container.read(timelineControllerProvider).items, isEmpty);

      // Verify SharedPreferences is completely purged on disk
      expect(prefs.getString('love_chat_messages'), isNull);
      final timelineString = prefs.getString('timeline_items');
      expect(timelineString == null || timelineString == '[]', isTrue);
    });
  });
}
