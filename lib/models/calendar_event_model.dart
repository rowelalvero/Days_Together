import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum CalendarEventType {
  anniversary,
  birthday,
  date,
  travel,
  other,
}

class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final TimeOfDay? time;
  final CalendarEventType type;
  final bool isRecurringYearly;

  CalendarEvent({
    String? id,
    required this.title,
    this.description,
    required this.date,
    this.time,
    this.type = CalendarEventType.other,
    this.isRecurringYearly = false,
  }) : id = id ?? const Uuid().v4();

  CalendarEvent copyWith({
    String? title,
    String? description,
    DateTime? date,
    TimeOfDay? time,
    CalendarEventType? type,
    bool? isRecurringYearly,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      type: type ?? this.type,
      isRecurringYearly: isRecurringYearly ?? this.isRecurringYearly,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'hour': time?.hour,
        'minute': time?.minute,
        'type': type.index,
        'isRecurringYearly': isRecurringYearly,
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      time: json['hour'] != null
          ? TimeOfDay(hour: json['hour'], minute: json['minute'])
          : null,
      type: CalendarEventType.values[json['type'] ?? 4],
      isRecurringYearly: json['isRecurringYearly'] ?? false,
    );
  }
}
