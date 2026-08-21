import 'package:uuid/uuid.dart';

/// Sentinel value used to distinguish "not provided" from "explicitly null"
/// in [TimelineItemData.copyWith] for nullable fields. This lets callers
/// clear a previously-set nullable field.
const Object _unset = Object();

class CommentData {
  final String id;
  final String authorName;
  final String content;
  final DateTime date;
  final bool isPinned;

  CommentData({
    String? id,
    required this.authorName,
    required this.content,
    required this.date,
    this.isPinned = false,
  }) : id = id ?? const Uuid().v4();

  CommentData copyWith({
    String? id,
    String? authorName,
    String? content,
    DateTime? date,
    bool? isPinned,
  }) {
    return CommentData(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      content: content ?? this.content,
      date: date ?? this.date,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': authorName,
        'content': content,
        'date': date.toIso8601String(),
        'isPinned': isPinned,
      };

  factory CommentData.fromJson(Map<String, dynamic> json) {
    return CommentData(
      id: json['id'] as String?,
      authorName: json['authorName'] as String? ?? 'Someone',
      content: json['content'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }
}

class TimelineItemData {
  final String id;
  final String title;
  final String description;
  final String? location; // New field for where it happened
  final String? imagePath;
  final String? networkImageUrl;
  final DateTime date;
  final bool isImageCard;
  final int position;
  final String mood;
  final List<String> photoUrls; // Up to 3 photos
  final bool isPinned; // Featured on widget
  final List<CommentData> comments;

  TimelineItemData({
    String? id,
    required this.title,
    required this.description,
    this.location,
    this.imagePath,
    this.networkImageUrl,
    required this.date,
    required this.isImageCard,
    required this.position,
    this.mood = '😍',
    this.photoUrls = const [],
    this.isPinned = false,
    this.comments = const [],
  }) : id = id ?? const Uuid().v4();

  /// Returns a copy with the given fields replaced.
  ///
  /// For nullable fields ([imagePath], [networkImageUrl]) passing `null`
  /// explicitly clears the field. Pass nothing (or rely on the default
  /// sentinel) to keep the existing value.
  TimelineItemData copyWith({
    String? id,
    String? title,
    String? description,
    Object? location = _unset,
    Object? imagePath = _unset,
    Object? networkImageUrl = _unset,
    DateTime? date,
    bool? isImageCard,
    int? position,
    String? mood,
    List<String>? photoUrls,
    bool? isPinned,
    List<CommentData>? comments,
  }) {
    return TimelineItemData(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: identical(location, _unset)
          ? this.location
          : location as String?,
      imagePath: identical(imagePath, _unset)
          ? this.imagePath
          : imagePath as String?,
      networkImageUrl: identical(networkImageUrl, _unset)
          ? this.networkImageUrl
          : networkImageUrl as String?,
      date: date ?? this.date,
      isImageCard: isImageCard ?? this.isImageCard,
      position: position ?? this.position,
      mood: mood ?? this.mood,
      photoUrls: photoUrls ?? this.photoUrls,
      isPinned: isPinned ?? this.isPinned,
      comments: comments ?? this.comments,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'location': location,
    'imagePath': imagePath,
    'networkImageUrl': networkImageUrl,
    'date': date.toIso8601String(),
    'isImageCard': isImageCard,
    'position': position,
    'mood': mood,
    'photoUrls': photoUrls,
    'isPinned': isPinned,
    'comments': comments.map((c) => c.toJson()).toList(),
  };

  factory TimelineItemData.fromJson(Map<String, dynamic> json) {
    return TimelineItemData(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String?,
      imagePath: json['imagePath'] as String?,
      networkImageUrl: json['networkImageUrl'] as String?,
      date: DateTime.parse(json['date'] as String),
      isImageCard: json['isImageCard'] as bool? ?? false,
      position: json['position'] as int? ?? 0,
      mood: json['mood'] as String? ?? '😍',
      photoUrls: List<String>.from(json['photoUrls'] as List? ?? []),
      isPinned: json['isPinned'] as bool? ?? false,
      comments: (json['comments'] as List? ?? [])
          .map((c) => CommentData.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
