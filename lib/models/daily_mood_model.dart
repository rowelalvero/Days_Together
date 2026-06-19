import 'package:uuid/uuid.dart';

class DailyMood {
  String id;
  String date; // YYYY-MM-DD format for easy querying
  int moodScore; // 1 to 10
  String? note;
  DateTime createdAt;

  DailyMood({
    String? id,
    required this.date,
    required this.moodScore,
    this.note,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  DailyMood copyWith({
    String? id,
    String? date,
    int? moodScore,
    String? note,
    DateTime? createdAt,
  }) {
    return DailyMood(
      id: id ?? this.id,
      date: date ?? this.date,
      moodScore: moodScore ?? this.moodScore,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'moodScore': moodScore,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DailyMood.fromJson(Map<String, dynamic> json) {
    return DailyMood(
      id: json['id'] as String?,
      date: json['date'] as String? ?? '',
      moodScore: json['moodScore'] as int? ?? 5,
      note: json['note'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

class DailySyncQuestion {
  String question;
  String? myAnswer;
  String? partnerAnswer;
  String date; // YYYY-MM-DD

  DailySyncQuestion({
    required this.question,
    this.myAnswer,
    this.partnerAnswer,
    required this.date,
  });

  bool get bothAnswered => myAnswer != null && partnerAnswer != null;

  Map<String, dynamic> toJson() => {
        'question': question,
        'myAnswer': myAnswer,
        'partnerAnswer': partnerAnswer,
        'date': date,
      };

  factory DailySyncQuestion.fromJson(Map<String, dynamic> json) {
    return DailySyncQuestion(
      question: json['question'] as String? ?? '',
      myAnswer: json['myAnswer'] as String?,
      partnerAnswer: json['partnerAnswer'] as String?,
      date: json['date'] as String? ?? '',
    );
  }
}
