/// Sentinel value used to distinguish "not provided" from "explicitly null"
/// in [AppSettings.copyWith] for nullable fields. Lets callers clear a
/// previously-set nullable field.
const Object _unset = Object();

enum ThemeType { midnightRose, liquidGlass, pink, deepPurple, offWhite, custom }

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
