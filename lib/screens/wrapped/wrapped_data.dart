import 'dart:convert';

/// Immutable snapshot of a couple's year-in-review.
/// Computed once by [WrappedService] and passed to all pages.
/// Fully serializable for archiving in SharedPreferences.
class WrappedData {
  final int year;
  final String yourName;
  final String? partnerName;
  final String? yourAvatarUrl;
  final String? partnerAvatarUrl;

  // Relationship duration at snapshot time
  final int totalDays;
  final int durationYears;
  final int durationMonths;
  final int durationDays;
  final DateTime? startDate;

  // Memories
  final int totalMemories;
  final int memoriesThisYear;
  final String? featuredMemoryTitle;
  final String? featuredMemoryDescription;
  final String? featuredMemoryImageUrl;
  final String? featuredMemoryImagePath;
  final DateTime? featuredMemoryDate;

  // Notes
  final int totalNotes;
  final int notesThisYear;
  final String? longestNoteExcerpt;

  // Bucket List
  final int bucketTotal;
  final int bucketCompleted;
  final int bucketCompletedThisYear;
  final String? favoriteBucketItem;

  // Mood
  final List<MonthlyMood> monthlyMoods;
  final double avgMoodScore;
  final int topMoodScore;
  final String? bestMoodMonth;

  // Calendar
  final int calendarEventsThisYear;
  final List<String> specialDatesThisYear;

  // Time Capsule
  final int capsulesCreated;
  final int capsulesOpened;
  final int upcomingCapsules;

  // Other stats
  final int totalPhotos;
  final int totalCapsules;

  // Milestones
  final List<String> milestonesAchievedThisYear;

  // Letter template seed (rotates by year mod 4)
  final int letterTemplateIndex;

  const WrappedData({
    required this.year,
    required this.yourName,
    this.partnerName,
    this.yourAvatarUrl,
    this.partnerAvatarUrl,
    required this.totalDays,
    required this.durationYears,
    required this.durationMonths,
    required this.durationDays,
    this.startDate,
    required this.totalMemories,
    required this.memoriesThisYear,
    this.featuredMemoryTitle,
    this.featuredMemoryDescription,
    this.featuredMemoryImageUrl,
    this.featuredMemoryImagePath,
    this.featuredMemoryDate,
    required this.totalNotes,
    required this.notesThisYear,
    this.longestNoteExcerpt,
    required this.bucketTotal,
    required this.bucketCompleted,
    required this.bucketCompletedThisYear,
    this.favoriteBucketItem,
    required this.monthlyMoods,
    required this.avgMoodScore,
    required this.topMoodScore,
    this.bestMoodMonth,
    required this.calendarEventsThisYear,
    required this.specialDatesThisYear,
    required this.capsulesCreated,
    required this.capsulesOpened,
    required this.upcomingCapsules,
    required this.totalPhotos,
    required this.totalCapsules,
    required this.milestonesAchievedThisYear,
    required this.letterTemplateIndex,
  });

  String get displayYear => year.toString();

  String get partnerDisplayName => partnerName ?? 'your partner';

  bool get hasFeaturedImage =>
      (featuredMemoryImageUrl?.isNotEmpty ?? false) ||
      (featuredMemoryImagePath?.isNotEmpty ?? false);

  bool get hasMoodData => monthlyMoods.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'year': year,
        'yourName': yourName,
        'partnerName': partnerName,
        'yourAvatarUrl': yourAvatarUrl,
        'partnerAvatarUrl': partnerAvatarUrl,
        'totalDays': totalDays,
        'durationYears': durationYears,
        'durationMonths': durationMonths,
        'durationDays': durationDays,
        'startDate': startDate?.toIso8601String(),
        'totalMemories': totalMemories,
        'memoriesThisYear': memoriesThisYear,
        'featuredMemoryTitle': featuredMemoryTitle,
        'featuredMemoryDescription': featuredMemoryDescription,
        'featuredMemoryImageUrl': featuredMemoryImageUrl,
        'featuredMemoryImagePath': featuredMemoryImagePath,
        'featuredMemoryDate': featuredMemoryDate?.toIso8601String(),
        'totalNotes': totalNotes,
        'notesThisYear': notesThisYear,
        'longestNoteExcerpt': longestNoteExcerpt,
        'bucketTotal': bucketTotal,
        'bucketCompleted': bucketCompleted,
        'bucketCompletedThisYear': bucketCompletedThisYear,
        'favoriteBucketItem': favoriteBucketItem,
        'monthlyMoods': monthlyMoods.map((m) => m.toJson()).toList(),
        'avgMoodScore': avgMoodScore,
        'topMoodScore': topMoodScore,
        'bestMoodMonth': bestMoodMonth,
        'calendarEventsThisYear': calendarEventsThisYear,
        'specialDatesThisYear': specialDatesThisYear,
        'capsulesCreated': capsulesCreated,
        'capsulesOpened': capsulesOpened,
        'upcomingCapsules': upcomingCapsules,
        'totalPhotos': totalPhotos,
        'totalCapsules': totalCapsules,
        'milestonesAchievedThisYear': milestonesAchievedThisYear,
        'letterTemplateIndex': letterTemplateIndex,
      };

  String toJsonString() => jsonEncode(toJson());

  factory WrappedData.fromJson(Map<String, dynamic> json) => WrappedData(
        year: json['year'] as int? ?? DateTime.now().year,
        yourName: json['yourName'] as String? ?? 'You',
        partnerName: json['partnerName'] as String?,
        yourAvatarUrl: json['yourAvatarUrl'] as String?,
        partnerAvatarUrl: json['partnerAvatarUrl'] as String?,
        totalDays: json['totalDays'] as int? ?? 0,
        durationYears: json['durationYears'] as int? ?? 0,
        durationMonths: json['durationMonths'] as int? ?? 0,
        durationDays: json['durationDays'] as int? ?? 0,
        startDate: json['startDate'] != null
            ? DateTime.tryParse(json['startDate'] as String)
            : null,
        totalMemories: json['totalMemories'] as int? ?? 0,
        memoriesThisYear: json['memoriesThisYear'] as int? ?? 0,
        featuredMemoryTitle: json['featuredMemoryTitle'] as String?,
        featuredMemoryDescription:
            json['featuredMemoryDescription'] as String?,
        featuredMemoryImageUrl: json['featuredMemoryImageUrl'] as String?,
        featuredMemoryImagePath: json['featuredMemoryImagePath'] as String?,
        featuredMemoryDate: json['featuredMemoryDate'] != null
            ? DateTime.tryParse(json['featuredMemoryDate'] as String)
            : null,
        totalNotes: json['totalNotes'] as int? ?? 0,
        notesThisYear: json['notesThisYear'] as int? ?? 0,
        longestNoteExcerpt: json['longestNoteExcerpt'] as String?,
        bucketTotal: json['bucketTotal'] as int? ?? 0,
        bucketCompleted: json['bucketCompleted'] as int? ?? 0,
        bucketCompletedThisYear: json['bucketCompletedThisYear'] as int? ?? 0,
        favoriteBucketItem: json['favoriteBucketItem'] as String?,
        monthlyMoods: (json['monthlyMoods'] as List? ?? [])
            .map((e) => MonthlyMood.fromJson(e as Map<String, dynamic>))
            .toList(),
        avgMoodScore: (json['avgMoodScore'] as num?)?.toDouble() ?? 0.0,
        topMoodScore: json['topMoodScore'] as int? ?? 0,
        bestMoodMonth: json['bestMoodMonth'] as String?,
        calendarEventsThisYear: json['calendarEventsThisYear'] as int? ?? 0,
        specialDatesThisYear: List<String>.from(
            json['specialDatesThisYear'] as List? ?? []),
        capsulesCreated: json['capsulesCreated'] as int? ?? 0,
        capsulesOpened: json['capsulesOpened'] as int? ?? 0,
        upcomingCapsules: json['upcomingCapsules'] as int? ?? 0,
        totalPhotos: json['totalPhotos'] as int? ?? 0,
        totalCapsules: json['totalCapsules'] as int? ?? 0,
        milestonesAchievedThisYear: List<String>.from(
            json['milestonesAchievedThisYear'] as List? ?? []),
        letterTemplateIndex: json['letterTemplateIndex'] as int? ?? 0,
      );

  factory WrappedData.fromJsonString(String jsonString) =>
      WrappedData.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
}

class MonthlyMood {
  final int month; // 1–12
  final double avgScore;
  final int count;

  const MonthlyMood({
    required this.month,
    required this.avgScore,
    required this.count,
  });

  Map<String, dynamic> toJson() => {
        'month': month,
        'avgScore': avgScore,
        'count': count,
      };

  factory MonthlyMood.fromJson(Map<String, dynamic> json) => MonthlyMood(
        month: json['month'] as int? ?? 1,
        avgScore: (json['avgScore'] as num?)?.toDouble() ?? 0.0,
        count: json['count'] as int? ?? 0,
      );
}
