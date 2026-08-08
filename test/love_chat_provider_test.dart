import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/models/love_chat_model.dart';
import 'package:days_together/providers/love_chat_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoveChatProvider M-1 Bounded Local Chat Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. 0 messages (empty state / welcome message prepopulation)', () async {
      final provider = LoveChatProvider();
      await Future.delayed(Duration.zero);
      expect(provider.messages.length, 1);
      expect(provider.messages.first.senderId, 'partner');
      provider.dispose();
    });

    test('2. 1 message persisted and loaded correctly', () async {
      final now = DateTime.now();
      final msg = LoveChatMessage(
        id: 'msg-1',
        senderId: 'you',
        senderName: 'Me',
        content: 'Hello love!',
        createdAt: now,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('love_chat_messages', jsonEncode([msg.toJson()]));

      final provider = LoveChatProvider();
      await Future.delayed(Duration.zero);

      expect(provider.messages.length, 1);
      expect(provider.messages.first.id, 'msg-1');
      expect(provider.messages.first.content, 'Hello love!');
      provider.dispose();
    });

    test('3. Exactly 200 messages retained without loss', () async {
      final now = DateTime.now();
      final List<Map<String, dynamic>> rawList = [];
      for (int i = 0; i < 200; i++) {
        rawList.add(
          LoveChatMessage(
            id: 'msg-$i',
            senderId: 'you',
            senderName: 'Me',
            content: 'Message $i',
            createdAt: now.subtract(Duration(minutes: i)),
          ).toJson(),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('love_chat_messages', jsonEncode(rawList));

      final provider = LoveChatProvider();
      await Future.delayed(Duration.zero);

      expect(provider.messages.length, 200);
      expect(provider.messages.first.id, 'msg-0');
      expect(provider.messages.last.id, 'msg-199');
      provider.dispose();
    });

    test('4. 201 messages clamped strictly to 200 on load and save', () async {
      final now = DateTime.now();
      final List<Map<String, dynamic>> rawList = [];
      for (int i = 0; i < 201; i++) {
        rawList.add(
          LoveChatMessage(
            id: 'msg-$i',
            senderId: 'you',
            senderName: 'Me',
            content: 'Message $i',
            createdAt: now.subtract(Duration(minutes: i)),
          ).toJson(),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('love_chat_messages', jsonEncode(rawList));

      final provider = LoveChatProvider();
      await Future.delayed(Duration.zero);

      expect(provider.messages.length, 200);
      expect(provider.messages.first.id, 'msg-0');
      expect(provider.messages.last.id, 'msg-199');
      provider.dispose();
    });

    test('5. 1,000 messages clamped strictly to 200 on load and save', () async {
      final now = DateTime.now();
      final List<Map<String, dynamic>> rawList = [];
      for (int i = 0; i < 1000; i++) {
        rawList.add(
          LoveChatMessage(
            id: 'msg-$i',
            senderId: 'you',
            senderName: 'Me',
            content: 'Message $i',
            createdAt: now.subtract(Duration(minutes: i)),
          ).toJson(),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('love_chat_messages', jsonEncode(rawList));

      final provider = LoveChatProvider();
      await Future.delayed(Duration.zero);

      expect(provider.messages.length, 200);
      expect(provider.messages.first.id, 'msg-0');
      expect(provider.messages.last.id, 'msg-199');
      provider.dispose();
    });

    test('6. Malformed stored JSON falls back safely without crash', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('love_chat_messages', '{invalid_json_corrupted}');

      final provider = LoveChatProvider();
      await Future.delayed(Duration.zero);

      expect(provider.messages, isEmpty);
      expect(provider.isLoading, false);
      provider.dispose();
    });

    test('7. Duplicate persistence calls maintain maxLocalMessages cap', () async {
      final provider = LoveChatProvider();
      await Future.delayed(Duration.zero);

      for (int i = 0; i < 250; i++) {
        await provider.sendMessage('Test content $i', 'Me');
      }

      expect(provider.messages.length, 200);
      expect(provider.messages.first.content, 'Test content 249');

      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('love_chat_messages');
      expect(jsonString, isNotNull);
      final jsonList = jsonDecode(jsonString!) as List;
      expect(jsonList.length, 200);
      provider.dispose();
    });

    test('8. App restart / reload simulation restores bounded state', () async {
      final now = DateTime.now();
      final List<Map<String, dynamic>> rawList = [];
      for (int i = 0; i < 50; i++) {
        rawList.add(
          LoveChatMessage(
            id: 'restart-msg-$i',
            senderId: 'you',
            senderName: 'Me',
            content: 'Persistent $i',
            createdAt: now.subtract(Duration(seconds: i)),
          ).toJson(),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('love_chat_messages', jsonEncode(rawList));

      // App Instance 1
      final provider1 = LoveChatProvider();
      await Future.delayed(Duration.zero);
      expect(provider1.messages.length, 50);
      provider1.dispose();

      // App Instance 2 (Simulating App Restart)
      final provider2 = LoveChatProvider();
      await Future.delayed(Duration.zero);
      expect(provider2.messages.length, 50);
      expect(provider2.messages.first.id, 'restart-msg-0');
      provider2.dispose();
    });

    test('9. Ordering preservation (newest messages first)', () async {
      final now = DateTime.now();
      final oldMsg = LoveChatMessage(
        id: 'old',
        senderId: 'you',
        senderName: 'Me',
        content: 'Old',
        createdAt: now.subtract(const Duration(hours: 2)),
      );
      final newMsg = LoveChatMessage(
        id: 'new',
        senderId: 'you',
        senderName: 'Me',
        content: 'New',
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'love_chat_messages',
        jsonEncode([oldMsg.toJson(), newMsg.toJson()]),
      );

      final provider = LoveChatProvider();
      await Future.delayed(Duration.zero);

      expect(provider.messages.first.id, 'new');
      expect(provider.messages.last.id, 'old');
      provider.dispose();
    });

    test('10. Migration from old oversized local cache (>200 messages)', () async {
      final now = DateTime.now();
      final List<Map<String, dynamic>> oversizedList = [];
      for (int i = 0; i < 500; i++) {
        oversizedList.add(
          LoveChatMessage(
            id: 'legacy-$i',
            senderId: 'you',
            senderName: 'Me',
            content: 'Legacy message $i',
            createdAt: now.subtract(Duration(minutes: i)),
          ).toJson(),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('love_chat_messages', jsonEncode(oversizedList));

      expect((jsonDecode(prefs.getString('love_chat_messages')!) as List).length, 500);

      final provider = LoveChatProvider();
      await Future.delayed(Duration.zero);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.messages.length, 200);

      final migratedDiskJson = prefs.getString('love_chat_messages');
      expect(migratedDiskJson, isNotNull);
      final migratedList = jsonDecode(migratedDiskJson!) as List;
      expect(migratedList.length, 200);
      expect((migratedList.first as Map)['id'], 'legacy-0');
      expect((migratedList.last as Map)['id'], 'legacy-199');

      provider.dispose();
    });
  });
}
