import 'package:uuid/uuid.dart';

class BucketListItem {
  String id;
  String title;
  bool isCompleted;
  DateTime? completedAt;
  int order;
  DateTime createdAt;
  DateTime? scheduledAt; // Added optional date/time

  BucketListItem({
    String? id,
    required this.title,
    this.isCompleted = false,
    this.completedAt,
    required this.order,
    DateTime? createdAt,
    this.scheduledAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  BucketListItem copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? completedAt,
    int? order,
    DateTime? createdAt,
    Object? scheduledAt = _unset, // Using sentinel for nullable
  }) {
    return BucketListItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      scheduledAt: identical(scheduledAt, _unset)
          ? this.scheduledAt
          : scheduledAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'scheduledAt': scheduledAt?.toIso8601String(),
      };

  factory BucketListItem.fromJson(Map<String, dynamic> json) {
    return BucketListItem(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      order: json['order'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.parse(json['scheduledAt'] as String)
          : null,
    );
  }
}

const Object _unset = Object();
