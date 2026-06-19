import 'package:uuid/uuid.dart';

class GiftReminder {
  String id;
  String title;
  DateTime date;
  List<int> reminderDaysBefore; // e.g. [30, 14, 7]
  bool isEnabled;
  bool isRecurringYearly;
  DateTime createdAt;

  GiftReminder({
    String? id,
    required this.title,
    required this.date,
    this.reminderDaysBefore = const [30, 14, 7],
    this.isEnabled = true,
    this.isRecurringYearly = true,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Returns the next occurrence of this reminder date.
  DateTime get nextOccurrence {
    final now = DateTime.now();
    var next = DateTime(now.year, date.month, date.day, date.hour, date.minute);
    if (next.isBefore(now)) {
      next = DateTime(now.year + 1, date.month, date.day, date.hour, date.minute);
    }
    return next;
  }

  /// Days until the next occurrence.
  int get daysUntil => nextOccurrence.difference(DateTime.now()).inDays;

  GiftReminder copyWith({
    String? id,
    String? title,
    DateTime? date,
    List<int>? reminderDaysBefore,
    bool? isEnabled,
    bool? isRecurringYearly,
    DateTime? createdAt,
  }) {
    return GiftReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      isEnabled: isEnabled ?? this.isEnabled,
      isRecurringYearly: isRecurringYearly ?? this.isRecurringYearly,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'reminderDaysBefore': reminderDaysBefore,
        'isEnabled': isEnabled,
        'isRecurringYearly': isRecurringYearly,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GiftReminder.fromJson(Map<String, dynamic> json) {
    return GiftReminder(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      reminderDaysBefore: (json['reminderDaysBefore'] as List?)
              ?.map((e) => e as int)
              .toList() ??
          [30, 14, 7],
      isEnabled: json['isEnabled'] as bool? ?? true,
      isRecurringYearly: json['isRecurringYearly'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
