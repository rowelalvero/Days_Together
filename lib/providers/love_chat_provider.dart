import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/models/love_chat_model.dart';

import 'package:days_together/services/relationship_lifecycle_manager.dart';

class LoveChatProvider extends SupabaseLifecycleProvider {
  static const String _storageKey = 'love_chat_messages';
  static const int maxLocalMessages = 200;

  List<LoveChatMessage> _messages = [];
  bool _isLoading = true;

  List<LoveChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;

  @override
  String get tableName => 'love_notes';

  LoveChatProvider() : super() {
    _loadMessages();
  }

  @override
  Future<void> purgeCache() async {
    _messages = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
    if (!isDisposed) notifyListeners();
  }

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    try {
      final List<dynamic> res = await Supabase.instance.client
          .from('love_notes')
          .select()
          .eq('couple_id', coupleId!)
          .eq('type', 'chat')
          .order('created_at', ascending: false)
          .limit(maxLocalMessages);

      final parsed = res
          .map((data) {
            final senderId = data['sender_id'] as String? ?? '';
            final senderType = (senderId == userId) ? 'you' : 'partner';
            return LoveChatMessage(
              id: data['id'] as String,
              senderId: senderType,
              senderName: (senderType == 'you') ? 'Me' : 'Partner',
              content: data['content'] as String? ?? '',
              createdAt: data['created_at'] != null
                  ? DateTime.parse(data['created_at'] as String).toLocal()
                  : DateTime.now(),
              isPinned: false,
            );
          })
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _messages = parsed.take(maxLocalMessages).toList();
      await _persistLocalOnly();
      if (!isDisposed) notifyListeners();
    } catch (e) {
      debugPrint('LoveChatProvider.syncInitialData error: $e');
    }
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    final parsed = dataList
        .where((data) => data['type'] == 'chat')
        .map((data) {
          final senderId = data['sender_id'] as String? ?? '';
          final senderType = (senderId == userId) ? 'you' : 'partner';
          return LoveChatMessage(
            id: data['id'] as String,
            senderId: senderType,
            senderName: (senderType == 'you') ? 'Me' : 'Partner',
            content: data['content'] as String? ?? '',
            createdAt: data['created_at'] != null
                ? DateTime.parse(data['created_at'] as String).toLocal()
                : DateTime.now(),
            isPinned: false,
          );
        })
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _messages = parsed.take(maxLocalMessages).toList();
    _isLoading = false;
    if (!isDisposed) notifyListeners();
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('LoveChatProvider: Supabase sync error: $error');
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    _isLoading = true;
    if (!isDisposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        final List<LoveChatMessage> parsedList = [];
        for (final item in jsonList) {
          try {
            if (item is Map<String, dynamic>) {
              parsedList.add(LoveChatMessage.fromJson(item));
            } else if (item is Map) {
              parsedList.add(
                LoveChatMessage.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          } catch (itemErr) {
            debugPrint('LoveChatProvider: skipping malformed chat item: $itemErr');
          }
        }

        parsedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final bool hadExcess = parsedList.length > maxLocalMessages;
        _messages = parsedList.take(maxLocalMessages).toList();

        // Migrate/trim oversized legacy SharedPreferences cache on disk
        if (hadExcess) {
          _persistLocalOnly();
        }
      } else {
        _messages = [];
        _prepopulateWelcome();
      }
    } catch (e, st) {
      debugPrint('LoveChatProvider._loadMessages failed: $e\n$st');
      _messages = [];
    } finally {
      _isLoading = false;
      if (!isDisposed) notifyListeners();
    }
  }

  void _prepopulateWelcome() {
    _messages = [
      LoveChatMessage(
        senderId: 'partner',
        senderName: 'Partner',
        content:
            'Hi honey! Welcome to our private Love Chat! 💬 Type a message to chat with me.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];
    _persistLocalOnly();
  }

  Future<void> sendMessage(String content, String senderName) async {
    final newMessage = LoveChatMessage(
      senderId: 'you',
      senderName: senderName,
      content: content,
    );

    _messages.insert(0, newMessage);
    _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _messages = _messages.take(maxLocalMessages).toList();

    notifyListeners();
    await _persist();

    if (coupleId != null && userId != null) {
      try {
        await Supabase.instance.client.from('love_notes').upsert({
          'id': newMessage.id,
          'couple_id': coupleId,
          'type': 'chat',
          'content': content,
          'sender_id': userId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        // Trigger push notification to partner
        try {
          await Supabase.instance.client.functions.invoke(
            'send-push-notification',
            body: {
              'sender_id': userId,
              'title': 'New Love Note 💖',
              'body': content.length > 50
                  ? '${content.substring(0, 47)}...'
                  : content,
            },
          );
        } catch (fcmError) {
          debugPrint(
            'LoveChatProvider: Failed to trigger push notification: $fcmError',
          );
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

    if (coupleId != null) {
      try {
        await Supabase.instance.client
            .from('love_notes')
            .delete()
            .eq('id', messageId);
      } catch (e) {
        debugPrint('LoveChatProvider.deleteMessage Supabase error: $e');
      }
    }
  }

  Future<void> _persist() async {
    await _persistLocalOnly();
    if (!isDisposed) notifyListeners();
  }

  Future<void> _persistLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final boundedList = _messages.take(maxLocalMessages).toList();
      final jsonList = boundedList.map((m) => m.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('LoveChatProvider._persistLocalOnly failed: $e\n$st');
    }
  }
}
