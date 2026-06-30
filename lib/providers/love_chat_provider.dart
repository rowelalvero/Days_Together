import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/services/supabase_sync_service.dart';
import 'package:days_together/models/love_chat_model.dart';
import 'package:days_together/providers/relationship_provider.dart';

class LoveChatProvider with ChangeNotifier {
  static const String _storageKey = 'love_chat_messages';

  List<LoveChatMessage> _messages = [];
  bool _isLoading = true;
  bool _disposed = false;

  String? _coupleId;
  String? _userId;
  StreamSubscription? _syncSub;

  List<LoveChatMessage> get messages => _coupleId == null ? const [] : List.unmodifiable(_messages);
  bool get isLoading => _isLoading;

  LoveChatProvider() {
    _loadMessages();
  }

  void updateRelationship(RelationshipProvider relationship) {
    if (_coupleId != relationship.coupleId || _userId != relationship.userId) {
      _coupleId = relationship.coupleId;
      _userId = relationship.userId;

      _syncSub?.cancel();
      _syncSub = null;

      if (_coupleId != null && _userId != null && relationship.isFirebaseAvailable) {
        _initSupabaseSync();
      } else {
        _loadMessages();
      }
    }
  }

  void _initSupabaseSync() {
    if (_coupleId == null || _userId == null) return;
    _isLoading = true;
    if (!_disposed) notifyListeners();

    _syncSub = SupabaseSyncService.instance.subscribeToCoupleData(
      tableName: 'love_notes',
      coupleId: _coupleId!,
      onData: (dataList) {
      _messages = dataList
          .where((data) => data['type'] == 'chat')
          .map((data) {
        final senderId = data['sender_id'] as String? ?? '';
        final senderType = (senderId == _userId) ? 'you' : 'partner';
        return LoveChatMessage(
          id: data['id'] as String,
          senderId: senderType,
          senderName: (senderType == 'you') ? 'Me' : 'Partner',
          content: data['content'] as String? ?? '',
          createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'] as String) : DateTime.now(),
          isPinned: false,
        );
      }).toList();

      _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _isLoading = false;
      if (!_disposed) notifyListeners();
      _persistLocalOnly();
      },
      onError: (err) {
        debugPrint('LoveChatProvider: Supabase stream error: $err');
        _loadMessages();
      },
    );
  }

  Future<void> _loadMessages() async {
    _isLoading = true;
    if (!_disposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _messages = jsonList.map((j) => LoveChatMessage.fromJson(j)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _prepopulateWelcome();
      }
    } catch (e, st) {
      debugPrint('LoveChatProvider._loadMessages failed: $e\n$st');
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _prepopulateWelcome() {
    _messages = [
      LoveChatMessage(
        senderId: 'partner',
        senderName: 'Partner',
        content: 'Hi honey! Welcome to our private Love Chat! 💬 Type a message to chat with me.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];
    _persist();
  }

  Future<void> sendMessage(String content, String senderName) async {
    final newMessage = LoveChatMessage(
      senderId: 'you',
      senderName: senderName,
      content: content,
    );

    _messages.insert(0, newMessage);
    notifyListeners();
    await _persist();

    if (_coupleId != null && _userId != null) {
      try {
        await Supabase.instance.client.from('love_notes').upsert({
          'id': newMessage.id,
          'couple_id': _coupleId,
          'type': 'chat',
          'content': content,
          'sender_id': _userId,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Trigger push notification to partner
        try {
          await Supabase.instance.client.functions.invoke(
            'send-push-notification',
            body: {
              'sender_id': _userId,
              'title': 'New Love Note 💖',
              'body': content.length > 50 ? '${content.substring(0, 47)}...' : content,
            },
          );
        } catch (fcmError) {
          debugPrint('LoveChatProvider: Failed to trigger push notification: $fcmError');
        }
      } catch (e) {
        debugPrint('LoveChatProvider.sendMessage Supabase error: $e');
      }
    }
  }

  Future<void> deleteMessage(String messageId) async {
    _messages.removeWhere((m) => m.id == messageId);
    notifyListeners();
    await _persist();

    if (_coupleId != null) {
      try {
        await Supabase.instance.client.from('love_notes').delete().eq('id', messageId);
      } catch (e) {
        debugPrint('LoveChatProvider.deleteMessage Supabase error: $e');
      }
    }
  }

  Future<void> simulatePartnerResponse() async {
    final responses = [
      "Aww, you make my heart melt! 🥰",
      "Miss you so much! ❤️ Can't wait to see you.",
      "I was just thinking about you! 💕 What are you up to?",
      "You are the best thing that ever happened to me. 😘",
      "Sending you the biggest hug! 🫂",
    ];
    final random = Random();
    final replyContent = responses[random.nextInt(responses.length)];

    final reply = LoveChatMessage(
      senderId: 'partner',
      senderName: 'Honey',
      content: replyContent,
    );

    _messages.insert(0, reply);
    notifyListeners();
    await _persist();

    if (_coupleId != null) {
      try {
        await Supabase.instance.client.from('love_notes').upsert({
          'id': reply.id,
          'couple_id': _coupleId,
          'type': 'chat',
          'content': replyContent,
          'sender_id': 'partner_sim',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('LoveChatProvider.simulatePartnerResponse Supabase error: $e');
      }
    }
  }

  Future<void> _persist() async {
    await _persistLocalOnly();
    if (!_disposed) notifyListeners();
  }

  Future<void> _persistLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _messages.map((m) => m.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('LoveChatProvider._persistLocalOnly failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _disposed = true;
    super.dispose();
  }
}
