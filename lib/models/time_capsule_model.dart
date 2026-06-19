import 'package:uuid/uuid.dart';

class TimeCapsule {
  String id;
  String message;
  DateTime openDate;
  bool isOpened;
  DateTime createdAt;

  TimeCapsule({
    String? id,
    required this.message,
    required this.openDate,
    this.isOpened = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get canOpen => DateTime.now().isAfter(openDate) || 
      DateTime.now().year == openDate.year && 
      DateTime.now().month == openDate.month && 
      DateTime.now().day == openDate.day;

  Duration get timeUntilOpen => openDate.difference(DateTime.now());

  TimeCapsule copyWith({
    String? id,
    String? message,
    DateTime? openDate,
    bool? isOpened,
    DateTime? createdAt,
  }) {
    return TimeCapsule(
      id: id ?? this.id,
      message: message ?? this.message,
      openDate: openDate ?? this.openDate,
      isOpened: isOpened ?? this.isOpened,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'message': message,
        'openDate': openDate.toIso8601String(),
        'isOpened': isOpened,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TimeCapsule.fromJson(Map<String, dynamic> json) {
    return TimeCapsule(
      id: json['id'] as String?,
      message: json['message'] as String? ?? '',
      openDate: DateTime.parse(json['openDate'] as String),
      isOpened: json['isOpened'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
