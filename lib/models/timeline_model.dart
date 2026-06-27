import 'package:uuid/uuid.dart';

/// Sentinel value used to distinguish "not provided" from "explicitly null"
/// in [TimelineItemData.copyWith] and [AppSettings.copyWith] for nullable
/// fields. This lets callers clear a previously-set nullable field.
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
  String id;
  String title;
  String description;
  String? location; // New field for where it happened
  String? imagePath;
  String? networkImageUrl;
  DateTime date;
  bool isImageCard;
  int position;
  String mood;
  List<String> photoUrls; // Up to 3 photos
  bool isPinned; // Featured on widget
  List<CommentData> comments;

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

class AppSettings {
  ThemeType currentTheme;
  bool backgroundMusicEnabled;
  double musicVolume;
  String? selectedMusicPath;
  List<String> favoriteThemes;
  DateTime? relationshipStartDate;

  // Custom theme fields
  int customPrimaryColor;
  int customSecondaryColor;
  int customBackgroundColor;
  int customAccentColor;
  bool customIsDark;

  AppSettings({
    this.currentTheme = ThemeType.offWhite,
    this.backgroundMusicEnabled = false,
    this.musicVolume = 0.5,
    this.selectedMusicPath,
    this.favoriteThemes = const [],
    this.relationshipStartDate,
    this.customPrimaryColor = 0xFFFF6B9D,
    this.customSecondaryColor = 0xFFC44569,
    this.customBackgroundColor = 0xFF2C003E,
    this.customAccentColor = 0xFFFFB5C5,
    this.customIsDark = true,
  });

  /// Returns a copy with the given fields replaced.
  AppSettings copyWith({
    ThemeType? currentTheme,
    bool? backgroundMusicEnabled,
    double? musicVolume,
    Object? selectedMusicPath = _unset,
    List<String>? favoriteThemes,
    Object? relationshipStartDate = _unset,
    int? customPrimaryColor,
    int? customSecondaryColor,
    int? customBackgroundColor,
    int? customAccentColor,
    bool? customIsDark,
  }) {
    return AppSettings(
      currentTheme: currentTheme ?? this.currentTheme,
      backgroundMusicEnabled:
          backgroundMusicEnabled ?? this.backgroundMusicEnabled,
      musicVolume: musicVolume ?? this.musicVolume,
      selectedMusicPath: identical(selectedMusicPath, _unset)
          ? this.selectedMusicPath
          : selectedMusicPath as String?,
      favoriteThemes: favoriteThemes ?? this.favoriteThemes,
      relationshipStartDate: identical(relationshipStartDate, _unset)
          ? this.relationshipStartDate
          : relationshipStartDate as DateTime?,
      customPrimaryColor: customPrimaryColor ?? this.customPrimaryColor,
      customSecondaryColor: customSecondaryColor ?? this.customSecondaryColor,
      customBackgroundColor: customBackgroundColor ?? this.customBackgroundColor,
      customAccentColor: customAccentColor ?? this.customAccentColor,
      customIsDark: customIsDark ?? this.customIsDark,
    );
  }

  Map<String, dynamic> toJson() => {
    'currentTheme': currentTheme.index,
    'backgroundMusicEnabled': backgroundMusicEnabled,
    'musicVolume': musicVolume,
    'selectedMusicPath': selectedMusicPath,
    'favoriteThemes': favoriteThemes,
    'relationshipStartDate': relationshipStartDate?.toIso8601String(),
    'customPrimaryColor': customPrimaryColor,
    'customSecondaryColor': customSecondaryColor,
    'customBackgroundColor': customBackgroundColor,
    'customAccentColor': customAccentColor,
    'customIsDark': customIsDark,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final themeIndex = json['currentTheme'] as int? ?? 0;
    final theme = (themeIndex >= 0 && themeIndex < ThemeType.values.length)
        ? ThemeType.values[themeIndex]
        : ThemeType.midnightRose;
    return AppSettings(
      currentTheme: theme,
      backgroundMusicEnabled: json['backgroundMusicEnabled'] as bool? ?? false,
      musicVolume: (json['musicVolume'] as num?)?.toDouble() ?? 0.5,
      selectedMusicPath: json['selectedMusicPath'] as String?,
      favoriteThemes: List<String>.from(json['favoriteThemes'] as List? ?? []),
      relationshipStartDate: json['relationshipStartDate'] != null
          ? DateTime.parse(json['relationshipStartDate'] as String)
          : null,
      customPrimaryColor: json['customPrimaryColor'] as int? ?? 0xFFFF6B9D,
      customSecondaryColor: json['customSecondaryColor'] as int? ?? 0xFFC44569,
      customBackgroundColor: json['customBackgroundColor'] as int? ?? 0xFF2C003E,
      customAccentColor: json['customAccentColor'] as int? ?? 0xFFFFB5C5,
      customIsDark: json['customIsDark'] as bool? ?? true,
    );
  }
}

enum ThemeType { midnightRose, liquidGlass, pink, deepPurple, offWhite, custom }
