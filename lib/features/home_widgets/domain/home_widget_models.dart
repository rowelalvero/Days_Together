import 'package:days_together/shared/models/app_settings.dart';

enum HomeWidgetType {
  noteit2x2,
  daysTogether2x2,
  daysTogether4x2,
}

enum DaysCounterFormat {
  totalDays,
  yearsMonthsDays,
  compact,
}

class HomeWidgetConfig {
  final ThemeType themeType;
  final DaysCounterFormat counterFormat;
  final String customTitle;
  final String customMilestoneTag;
  final String? selectedDrawingId;
  final bool showSeconds;
  final bool showMilestone;

  const HomeWidgetConfig({
    this.themeType = ThemeType.midnightRose,
    this.counterFormat = DaysCounterFormat.totalDays,
    this.customTitle = 'Days Together',
    this.customMilestoneTag = '4th Anniversary',
    this.selectedDrawingId,
    this.showSeconds = true,
    this.showMilestone = true,
  });

  HomeWidgetConfig copyWith({
    ThemeType? themeType,
    DaysCounterFormat? counterFormat,
    String? customTitle,
    String? customMilestoneTag,
    String? selectedDrawingId,
    bool? showSeconds,
    bool? showMilestone,
  }) {
    return HomeWidgetConfig(
      themeType: themeType ?? this.themeType,
      counterFormat: counterFormat ?? this.counterFormat,
      customTitle: customTitle ?? this.customTitle,
      customMilestoneTag: customMilestoneTag ?? this.customMilestoneTag,
      selectedDrawingId: selectedDrawingId ?? this.selectedDrawingId,
      showSeconds: showSeconds ?? this.showSeconds,
      showMilestone: showMilestone ?? this.showMilestone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeType': themeType.name,
      'counterFormat': counterFormat.name,
      'customTitle': customTitle,
      'customMilestoneTag': customMilestoneTag,
      'selectedDrawingId': selectedDrawingId,
      'showSeconds': showSeconds,
      'showMilestone': showMilestone,
    };
  }

  factory HomeWidgetConfig.fromJson(Map<String, dynamic> json) {
    ThemeType resolvedTheme = ThemeType.midnightRose;
    if (json['themeType'] != null) {
      resolvedTheme = ThemeType.values.firstWhere(
        (e) => e.name == json['themeType'],
        orElse: () => ThemeType.midnightRose,
      );
    }

    DaysCounterFormat resolvedFormat = DaysCounterFormat.totalDays;
    if (json['counterFormat'] != null) {
      resolvedFormat = DaysCounterFormat.values.firstWhere(
        (e) => e.name == json['counterFormat'],
        orElse: () => DaysCounterFormat.totalDays,
      );
    }

    return HomeWidgetConfig(
      themeType: resolvedTheme,
      counterFormat: resolvedFormat,
      customTitle: json['customTitle'] as String? ?? 'Days Together',
      customMilestoneTag: json['customMilestoneTag'] as String? ?? '4th Anniversary',
      selectedDrawingId: json['selectedDrawingId'] as String?,
      showSeconds: json['showSeconds'] as bool? ?? true,
      showMilestone: json['showMilestone'] as bool? ?? true,
    );
  }
}
