import 'package:uuid/uuid.dart';

class LoveChatMessage {
  final String id;
  final String senderId; // 'you' or 'partner'
  final String senderName;
  final String content;
  final DateTime createdAt;
  final bool isPinned;

  LoveChatMessage({
    String? id,
    required this.senderId,
    required this.senderName,
    required this.content,
    DateTime? createdAt,
    this.isPinned = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  LoveChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? createdAt,
    bool? isPinned,
  }) {
    return LoveChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'isPinned': isPinned,
      };

  factory LoveChatMessage.fromJson(Map<String, dynamic> json) {
    return LoveChatMessage(
      id: json['id'] as String?,
      senderId: json['senderId'] as String? ?? 'you',
      senderName: json['senderName'] as String? ?? 'Me',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }
}
