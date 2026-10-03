import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/notifications/notification_service.dart';
import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/core/session/couple_session.dart';
import 'package:days_together/features/chat/love_chat_state.dart';
import 'package:days_together/features/chat/domain/entities/love_chat_model.dart';
import 'package:days_together/core/constants/tables.dart';
import 'package:days_together/core/storage/scoped_json_cache.dart';

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

/// Orders messages newest-first, breaking ties on the list's existing order.
///
/// `List.sort` is documented as **not** stable, and `DateTime.now()` routinely
/// repeats within the same millisecond for messages created in quick
/// succession. A plain `sort((a, b) => b.createdAt.compareTo(a.createdAt))`
/// therefore left same-millisecond messages in an arbitrary order: a
/// just-prepended message could be pushed out of position 0, and at the
/// [LoveChatController.maxLocalMessages] boundary it could be truncated away
/// entirely. Decorating each element with its original index makes the
/// ordering total, so ties keep the order they arrived in and the result is
/// deterministic.
///
/// This was previously visible only as an intermittent test failure
/// (`love_chat_controller_test.dart`'s maxLocalMessages cap, ~1 run in 3), but
/// the same tie affects real sends: two messages posted in the same
/// millisecond could display in either order.
List<LoveChatMessage> _sortedNewestFirst(Iterable<LoveChatMessage> messages) {
  final indexed = messages.toList().indexed.toList();
  indexed.sort((a, b) {
    final byRecency = b.$2.createdAt.compareTo(a.$2.createdAt);
    return byRecency != 0 ? byRecency : a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}

class LoveChatController extends Notifier<LoveChatState>
    with SupabaseLifecycleNotifier<LoveChatState> {
  static const ScopedJsonCache _cache = ScopedJsonCache('love_chat_messages');
  static const int maxLocalMessages = 200;

  @override
  String get tableName => Tables.loveNotes;

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
      final jsonString = await _cache.read();
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
            debugPrint(
              'LoveChatController: skipping malformed chat item: $itemErr',
            );
          }
        }

        final sortedList = _sortedNewestFirst(parsedList);
        final bool hadExcess = sortedList.length > maxLocalMessages;
        final bounded = sortedList.take(maxLocalMessages).toList();

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
        content:
            'Hi honey! Welcome to our private Love Chat! 💬 Type a message to chat with me.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];
  }

  @override
  Future<void> purgeCache() async {
    state = state.copyWith(messages: [], isLoading: false);
    await _cache.clearAll();
  }

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    try {
      final List<dynamic> res = await Supabase.instance.client
          .from(Tables.loveNotes)
          .select()
          .eq('couple_id', coupleId!)
          .eq('type', 'chat')
          .order('created_at', ascending: false)
          .limit(maxLocalMessages);

      final parsed = _sortedNewestFirst(res.map((data) => _parseMessage(data)));

      if (!ref.mounted) return;
      state = state.copyWith(
        messages: parsed.take(maxLocalMessages).toList(),
        isLoading: false,
      );
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
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String).toLocal()
          : DateTime.now(),
      isPinned: false,
    );
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    if (!ref.mounted) return;
    final parsed = _sortedNewestFirst(
      dataList
          .where((data) => data['type'] == 'chat')
          .map((data) => _parseMessage(data)),
    );

    state = state.copyWith(
      messages: parsed.take(maxLocalMessages).toList(),
      isLoading: false,
    );
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('LoveChatController: Supabase sync error: $error');
    _loadFromCache();
  }

  Future<void> sendMessage(String content, String senderName) async {
    final newMessage = LoveChatMessage(
      senderId: 'you',
      senderName: senderName,
      content: content,
    );

    final messages = _sortedNewestFirst([
      newMessage,
      ...state.messages,
    ]).take(maxLocalMessages).toList();
    state = state.copyWith(messages: messages);
    await _persist();

    if (coupleId != null && sessionUserId != null) {
      try {
        await Supabase.instance.client.from(Tables.loveNotes).upsert({
          'id': newMessage.id,
          'couple_id': coupleId,
          'type': 'chat',
          'content': content,
          'sender_id': sessionUserId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        // Through the canonical pathway with feature 'chat', so the partner's
        // chat_enabled preference applies and a tap opens the chat (audit
        // F-19). The body deliberately carries no message text: it is shown
        // on the lock screen and transits Google's push servers. The message
        // itself is stored above; a failed push is non-fatal and is swallowed
        // inside sendPartnerNotification.
        await NotificationService().sendPartnerNotification(
          title: 'New Love Note 💖',
          body: 'Your partner sent you a message.',
          feature: 'chat',
        );
      } catch (e) {
        // Rethrown rather than swallowed: the local optimistic write above has
        // already happened and is persisted, so the caller's UI stays correct,
        // but the message did *not* reach the partner. Callers that care --
        // ScrapbookShareUseCase, whose ScrapbookShareChatMirrorFailed result
        // was unreachable while this was a debugPrint -- need to be able to
        // tell.
        debugPrint('LoveChatController.sendMessage Supabase error: $e');
        rethrow;
      }
    }
  }

  Future<void> deleteMessage(String messageId) async {
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != messageId).toList(),
    );
    await _persist();

    if (coupleId != null) {
      try {
        await Supabase.instance.client
            .from(Tables.loveNotes)
            .delete()
            .eq('id', messageId);
      } catch (e) {
        debugPrint('LoveChatController.deleteMessage Supabase error: $e');
      }
    }
  }

  Future<void> _persist() => _persistLocalOnly();

  Future<void> _persistLocalOnly() async {
    try {
      final sorted = _sortedNewestFirst(state.messages);
      final bounded = sorted.take(maxLocalMessages).toList();
      final jsonList = bounded.map((m) => m.toJson()).toList();
      await _cache.write(jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('LoveChatController._persistLocalOnly failed: $e\n$st');
    }
  }
}

final loveChatControllerProvider =
    NotifierProvider.autoDispose<LoveChatController, LoveChatState>(
      LoveChatController.new,
      dependencies: [coupleSessionProvider],
    );
