import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/features/chat/presentation/widgets/chat_header.dart';
import 'package:days_together/features/chat/presentation/widgets/chat_input_row.dart';
import 'package:days_together/features/chat/presentation/widgets/chat_message_list.dart';
import 'package:days_together/features/relationship/presence_controller.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/core/models/scrapbook_ref.dart';
import 'package:days_together/features/chat/domain/entities/love_chat_model.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/features/scrapbook/noteit_state.dart';
import 'package:days_together/features/theme/theme_controller.dart';

/// The couple's private chat: a message feed (plain notes or mirrored
/// scrapbook creations) plus a compose row.
///
/// Its `_buildX` methods and inline dialog/sheet builders were extracted
/// into focused widgets under `presentation/widgets/`, `presentation/
/// dialogs/`, and `presentation/sheets/` (Migration audit item 6) -- this
/// class now only owns the message-compose/scroll/reveal state a chat
/// screen genuinely needs.
class LoveChatScreen extends ConsumerStatefulWidget {
  const LoveChatScreen({super.key});

  @override
  ConsumerState<LoveChatScreen> createState() => _LoveChatScreenState();
}

class _LoveChatScreenState extends ConsumerState<LoveChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _revealedMessageIds = {};

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(LoveChatController notifier, String senderName) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    // The local, optimistic part of sendMessage has already completed by the
    // time this can throw, so the message stays on screen either way -- this
    // only surfaces that it did not reach the partner (sendMessage now
    // rethrows its Supabase error instead of swallowing it).
    final send = notifier.sendMessage(text, senderName);
    _messageController.clear();
    send.catchError((Object _) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't send that to your partner — check your connection.",
          ),
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Note ids already requested by this screen, so a note that no longer
  /// exists is asked for once, not on every rebuild.
  final Set<String> _requestedNoteIds = {};

  /// Scrapbook-mirror messages refer to notes by id, and the scrapbook only
  /// keeps its newest page loaded: fetch the ones older messages point at.
  void _loadReferencedNotes(
    List<LoveChatMessage> messages,
    NoteitState noteit,
  ) {
    final missing = <String>[];
    for (final m in messages) {
      final id = ScrapbookRef.fromChatPayload(m.content)?.itemId.trim();
      if (id == null || id.startsWith('{')) continue;
      if (noteit.noteById(id) == null && _requestedNoteIds.add(id)) {
        missing.add(id);
      }
    }
    if (missing.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(noteitControllerProvider.notifier).ensureLoaded(missing);
      }
    });
  }

  void _toggleReveal(String messageId) {
    setState(() {
      if (_revealedMessageIds.contains(messageId)) {
        _revealedMessageIds.remove(messageId);
      } else {
        _revealedMessageIds.add(messageId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final profile = ref.watch(profileControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final chatState = ref.watch(loveChatControllerProvider);
    final chatNotifier = ref.read(loveChatControllerProvider.notifier);
    final noteitState = ref.watch(noteitControllerProvider);
    _loadReferencedNotes(chatState.messages, noteitState);

    final yourName = profile.yourName ?? 'Me';
    final partnerName = profile.partnerName ?? 'Partner';
    final partnerJoined = session.partnerId != null;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: Column(
            children: [
              ChatHeader(
                theme: theme,
                partnerAvatarPath: profile.partnerAvatarPath,
                isPartnerOnline: ref
                    .watch(presenceControllerProvider)
                    .isPartnerOnline,
                partnerJoined: partnerJoined,
                partnerName: partnerName,
              ),
              Divider(color: theme.textColor.withValues(alpha: 0.1), height: 1),
              Expanded(
                child: ChatMessageList(
                  messages: chatState.messages,
                  paging: chatState.paging,
                  scrollController: _scrollController,
                  theme: theme,
                  // knownNotes: also the notes older messages refer to,
                  // loaded on demand by _loadReferencedNotes.
                  visibleNotes: noteitState.knownNotes,
                  revealedMessageIds: _revealedMessageIds,
                  onToggleReveal: _toggleReveal,
                  notifier: chatNotifier,
                ),
              ),
              Divider(color: theme.textColor.withValues(alpha: 0.1), height: 1),
              ChatInputRow(
                controller: _messageController,
                theme: theme,
                onSend: () => _sendMessage(chatNotifier, yourName),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
