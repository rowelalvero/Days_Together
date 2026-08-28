import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/features/chat/love_chat_state.dart';
import 'package:days_together/models/love_chat_model.dart';

/// Riverpod port of `LoveChatProvider` (Phase 6a of the architecture
/// migration, ported together with `NoteitController` since both read the
/// `love_notes` table).
///
/// **The `love_notes` "collision" ADR-005/ADR-013 planned to fix by giving
/// each feature a distinct, server-side-`type`-filtered subscription key is
/// NOT implemented that way here -- it turns out to be technically
/// infeasible with the installed `supabase` package (2.13.0), not merely
/// deprioritized.** `SupabaseStreamBuilder` (the type `.stream()` returns)
/// stores its `.eq()` filter in a single nullable field,
/// `_StreamPostgrestFilter? _streamFilter` (`supabase_stream_builder.dart`,
/// verified directly against the installed package source) -- calling
/// `.eq()` twice does not combine two filters, it silently **overwrites**
/// the first. Chaining `.eq('couple_id', coupleId).eq('type', 'chat')` as
/// ADR-005 prescribed would drop the `couple_id` scoping entirely, a much
/// worse bug than the one it was meant to fix (every couple's chat rows,
/// not just this couple's). The same single-filter limit applies to the
/// lower-level `channel().onPostgresChanges(filter: PostgresChangeFilter)`
/// API this wraps, so bypassing `.stream()` doesn't route around it either
/// -- a true server-side compound filter would need a schema change (e.g.
/// a Postgres view per type), which is out of scope for an
/// application-layer migration phase and was explicitly ruled out for this
/// migration regardless (ADR-013: "the `love_notes` table's schema is not
/// touched by this migration").
///
/// So both `NoteitController` and `LoveChatController` keep `tableName =>
/// 'love_notes'`, deliberately sharing `SupabaseLifecycleNotifier`'s
/// default subscription key (`'love_notes_$coupleId'`) exactly as the
/// original `NoteitProvider`/`LoveChatProvider` did, each still filtering
/// client-side in `onRealtimeData`. This was never actually a bug: the
/// shared key is `RealtimeSubscriptionManager`'s deduplication doing
/// exactly its job (one physical subscription, two logical consumers) --
/// see this unit's roadmap entry for the corrections made to ADR-005 and
/// ADR-013 to stop describing it as one.
class LoveChatController extends Notifier<LoveChatState> with SupabaseLifecycleNotifier<LoveChatState> {
  static const String _storageKey = 'love_chat_messages';
  static const int maxLocalMessages = 200;

  @override
  String get tableName => 'love_notes';

  @override
  LoveChatState build() {
    // Per ADR-005: chat and scrapbook are exempted from autoDispose's
    // default teardown, since losing and re-establishing the realtime
    // subscription during a brief background/tab-switch would visibly drop
    // incoming messages during the gap.
    ref.keepAlive();
    initSessionLifecycle();
    _loadFromCache();
    return const LoveChatState();
  }

  Future<void> _loadFromCache() async {
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
              parsedList.add(LoveChatMessage.fromJson(Map<String, dynamic>.from(item)));
            }
          } catch (itemErr) {
            debugPrint('LoveChatController: skipping malformed chat item: $itemErr');
          }
        }

        parsedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final bool hadExcess = parsedList.length > maxLocalMessages;
        final bounded = parsedList.take(maxLocalMessages).toList();

        if (!ref.mounted) return;
        state = state.copyWith(messages: bounded, isLoading: false);
        // Migrate/trim oversized legacy SharedPreferences cache on disk.
        if (hadExcess) await _persistLocalOnly();
      } else {
        final welcome = _welcomeMessage();
        if (!ref.mounted) return;
        state = state.copyWith(messages: welcome, isLoading: false);
        await _persistLocalOnly();
      }
    } catch (e, st) {
      debugPrint('LoveChatController._loadFromCache failed: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(messages: [], isLoading: false);
    }
  }

  List<LoveChatMessage> _welcomeMessage() {
    return [
      LoveChatMessage(
        senderId: 'partner',
        senderName: 'Partner',
        content: 'Hi honey! Welcome to our private Love Chat! 💬 Type a message to chat with me.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];
  }

  @override
  Future<void> purgeCache() async {
    state = state.copyWith(messages: [], isLoading: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('LoveChatController.purgeCache error: $e');
    }
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

      final parsed = res.map((data) => _parseMessage(data)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!ref.mounted) return;
      state = state.copyWith(messages: parsed.take(maxLocalMessages).toList(), isLoading: false);
      await _persistLocalOnly();
    } catch (e) {
      debugPrint('LoveChatController.syncInitialData error: $e');
    }
  }

  LoveChatMessage _parseMessage(Map<String, dynamic> data) {
    final senderId = data['sender_id'] as String? ?? '';
    final senderType = (senderId == sessionUserId) ? 'you' : 'partner';
    return LoveChatMessage(
      id: data['id'] as String,
      senderId: senderType,
      senderName: (senderType == 'you') ? 'Me' : 'Partner',
      content: data['content'] as String? ?? '',
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'] as String).toLocal() : DateTime.now(),
      isPinned: false,
    );
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    if (!ref.mounted) return;
    final parsed = dataList.where((data) => data['type'] == 'chat').map((data) => _parseMessage(data)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    state = state.copyWith(messages: parsed.take(maxLocalMessages).toList(), isLoading: false);
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('LoveChatController: Supabase sync error: $error');
    _loadFromCache();
  }

  Future<void> sendMessage(String content, String senderName) async {
    final newMessage = LoveChatMessage(senderId: 'you', senderName: senderName, content: content);

    final messages = ([newMessage, ...state.messages]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        .take(maxLocalMessages)
        .toList();
    state = state.copyWith(messages: messages);
    await _persist();

    if (coupleId != null && sessionUserId != null) {
      try {
        await Supabase.instance.client.from('love_notes').upsert({
          'id': newMessage.id,
          'couple_id': coupleId,
          'type': 'chat',
          'content': content,
          'sender_id': sessionUserId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        try {
          await Supabase.instance.client.functions.invoke(
            'send-push-notification',
            body: {
              'sender_id': sessionUserId,
              'title': 'New Love Note 💖',
              'body': content.length > 50 ? '${content.substring(0, 47)}...' : content,
            },
          );
        } catch (fcmError) {
          debugPrint('LoveChatController: Failed to trigger push notification: $fcmError');
        }
      } catch (e) {
        debugPrint('LoveChatController.sendMessage Supabase error: $e');
      }
    }
  }

  Future<void> deleteMessage(String messageId) async {
    state = state.copyWith(messages: state.messages.where((m) => m.id != messageId).toList());
    await _persist();

    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('love_notes').delete().eq('id', messageId);
      } catch (e) {
        debugPrint('LoveChatController.deleteMessage Supabase error: $e');
      }
    }
  }

  Future<void> _persist() => _persistLocalOnly();

  Future<void> _persistLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sorted = [...state.messages]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final bounded = sorted.take(maxLocalMessages).toList();
      final jsonList = bounded.map((m) => m.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('LoveChatController._persistLocalOnly failed: $e\n$st');
    }
  }
}

final loveChatControllerProvider = NotifierProvider.autoDispose<LoveChatController, LoveChatState>(
  LoveChatController.new,
  dependencies: [coupleSessionProvider],
);
