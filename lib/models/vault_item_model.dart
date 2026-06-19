import 'package:uuid/uuid.dart';

enum VaultItemType { photo, letter }

class VaultItem {
  String id;
  VaultItemType type;
  String? content; // Text content for letters
  String? imagePath; // File path for photos
  String? imageUrl; // Firebase Storage URL for photos
  DateTime createdAt;

  VaultItem({
    String? id,
    required this.type,
    this.content,
    this.imagePath,
    this.imageUrl,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  VaultItem copyWith({
    String? id,
    VaultItemType? type,
    String? content,
    String? imagePath,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return VaultItem(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'content': content,
        'imagePath': imagePath,
        'imageUrl': imageUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    final typeIndex = json['type'] as int? ?? 0;
    return VaultItem(
      id: json['id'] as String?,
      type: (typeIndex >= 0 && typeIndex < VaultItemType.values.length)
          ? VaultItemType.values[typeIndex]
          : VaultItemType.photo,
      content: json['content'] as String?,
      imagePath: json['imagePath'] as String?,
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
