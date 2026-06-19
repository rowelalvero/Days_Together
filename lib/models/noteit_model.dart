import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum NoteitType { drawing, photo, text }

class NoteitItem {
  final String id;
  final NoteitType type;
  final String? content; // Text content for text notes, serialized strokes for drawings
  final String? imagePath; // Local file path for photos
  final String? imageUrl; // Remote Storage URL for photos
  final String sender; // 'you' or 'partner'
  final DateTime createdAt;
  final Color? backgroundColor;

  NoteitItem({
    String? id,
    required this.type,
    this.content,
    this.imagePath,
    this.imageUrl,
    required this.sender,
    DateTime? createdAt,
    this.backgroundColor,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  NoteitItem copyWith({
    String? id,
    NoteitType? type,
    String? content,
    String? imagePath,
    String? imageUrl,
    String? sender,
    DateTime? createdAt,
    Color? backgroundColor,
  }) {
    return NoteitItem(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      sender: sender ?? this.sender,
      createdAt: createdAt ?? this.createdAt,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'content': content,
        'imagePath': imagePath,
        'imageUrl': imageUrl,
        'sender': sender,
        'createdAt': createdAt.toIso8601String(),
        'backgroundColor': backgroundColor?.toARGB32(),
      };

  factory NoteitItem.fromJson(Map<String, dynamic> json) {
    final typeIndex = json['type'] as int? ?? 0;
    return NoteitItem(
      id: json['id'] as String?,
      type: (typeIndex >= 0 && typeIndex < NoteitType.values.length)
          ? NoteitType.values[typeIndex]
          : NoteitType.drawing,
      content: json['content'] as String?,
      imagePath: json['imagePath'] as String?,
      imageUrl: json['imageUrl'] as String?,
      sender: json['sender'] as String? ?? 'you',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      backgroundColor: json['backgroundColor'] != null
          ? Color(json['backgroundColor'] as int)
          : null,
    );
  }
}
