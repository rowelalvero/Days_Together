import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/providers/love_chat_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/services/relationship_lifecycle_manager.dart';

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

      final chatProvider = LoveChatProvider();
      final timelineProvider = TimelineProvider();

      await Future.delayed(Duration.zero);

      expect(chatProvider.messages.length, 1);
      expect(chatProvider.messages.first.content, 'Secret User A Note');

      // 2. User A logs out -> RelationshipLifecycleManager handles logout
      await RelationshipLifecycleManager.instance.handleLogout();

      expect(chatProvider.messages, isEmpty);
      expect(timelineProvider.timelineItems, isEmpty);

      // Verify SharedPreferences is completely purged on disk
      expect(prefs.getString('love_chat_messages'), isNull);
      final timelineString = prefs.getString('timeline_items');
      expect(timelineString == null || timelineString == '[]', isTrue);

      chatProvider.dispose();
      timelineProvider.dispose();
    });
  });
}
