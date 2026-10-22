import 'package:days_together/core/models/paging_status.dart';
import 'package:days_together/features/chat/domain/entities/love_chat_model.dart';

/// State for `LoveChatController` (Phase 6a of the architecture migration)
/// -- a direct Riverpod port of `LoveChatProvider`'s `_messages`/
/// `_isLoading` fields. [paging] covers OLDER history (scrolling up).
class LoveChatState {
  final List<LoveChatMessage> messages;
  final bool isLoading;
  final PagingStatus paging;

  const LoveChatState({
    this.messages = const [],
    this.isLoading = true,
    this.paging = const PagingStatus(),
  });

  LoveChatState copyWith({
    List<LoveChatMessage>? messages,
    bool? isLoading,
    PagingStatus? paging,
  }) {
    return LoveChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      paging: paging ?? this.paging,
    );
  }
}
