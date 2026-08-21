import 'package:days_together/models/love_chat_model.dart';

/// State for `LoveChatController` (Phase 6a of the architecture migration)
/// -- a direct Riverpod port of `LoveChatProvider`'s `_messages`/
/// `_isLoading` fields.
class LoveChatState {
  final List<LoveChatMessage> messages;
  final bool isLoading;

  const LoveChatState({this.messages = const [], this.isLoading = true});

  LoveChatState copyWith({List<LoveChatMessage>? messages, bool? isLoading}) {
    return LoveChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
