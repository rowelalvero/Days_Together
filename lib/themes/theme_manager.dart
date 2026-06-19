import 'package:days_together/models/timeline_model.dart';
import 'package:flutter/material.dart';

class ThemeManager {
  static Map<ThemeType, LoveStoryTheme> themes = {
    ThemeType.midnightRose: const LoveStoryTheme(
      name: 'Midnight Glass',
      primaryColor: Color(0xFF10122B),
      secondaryColor: Color(0xFF1A1B41),
      backgroundColor: Color(0xFF0A0B1A),
      textColor: Colors.white,
      cardColor: Color(0x1AFFFFFF),
      accentColor: Color(0xFFFF4D6D),
      isDark: true,
    ),
    ThemeType.liquidGlass: const LoveStoryTheme(
      name: 'Azure Liquid',
      primaryColor: Color(0xFF00B4D8),
      secondaryColor: Color(0xFF0077B6),
      backgroundColor: Color(0xFF03045E),
      textColor: Colors.white,
      cardColor: Color(0x26FFFFFF),
      accentColor: Color(0xFFADE8F4),
      isDark: true,
    ),
    ThemeType.pink: const LoveStoryTheme(
      name: 'Rose Quartz',
      primaryColor: Color(0xFFFF85A1),
      secondaryColor: Color(0xFFFFB3C1),
      backgroundColor: Color(0xFF590D22),
      textColor: Colors.white,
      cardColor: Color(0x1AFFFFFF),
      accentColor: Color(0xFFFFC4D6),
      isDark: true,
    ),
    ThemeType.deepPurple: const LoveStoryTheme(
      name: 'Neon Violet',
      primaryColor: Color(0xFF7B2CBF),
      secondaryColor: Color(0xFF9D4EDD),
      backgroundColor: Color(0xFF10002B),
      textColor: Colors.white,
      cardColor: Color(0x1AFFFFFF),
      accentColor: Color(0xFFE0AAFF),
      isDark: true,
    ),
    ThemeType.offWhite: const LoveStoryTheme(
      name: 'Lovely Off-White',
      primaryColor: Color(0xFFFFF0F5),
      secondaryColor: Color(0xFFFFE4EC),
      backgroundColor: Color(0xFFFFF8FA),
      textColor: Color(0xFF3D2C3E),
      cardColor: Color(0x15D4778A),
      accentColor: Color(0xFFE8477E),
      isDark: false,
    ),
  };

  static LoveStoryTheme getTheme(ThemeType type) {
    return themes[type] ?? themes[ThemeType.midnightRose]!;
  }

  /// Build a custom theme from AppSettings color values.
  static LoveStoryTheme buildCustomTheme(AppSettings settings) {
    return LoveStoryTheme(
      name: 'Custom',
      primaryColor: Color(settings.customPrimaryColor),
      secondaryColor: Color(settings.customSecondaryColor),
      backgroundColor: Color(settings.customBackgroundColor),
      textColor: settings.customIsDark ? Colors.white : const Color(0xFF3D2C3E),
      cardColor: settings.customIsDark
          ? const Color(0x1AFFFFFF)
          : const Color(0x15D4778A),
      accentColor: Color(settings.customAccentColor),
      isDark: settings.customIsDark,
    );
  }

  /// Resolve the active theme, accounting for custom type.
  static LoveStoryTheme resolveTheme(ThemeType type, AppSettings settings) {
    if (type == ThemeType.custom) {
      return buildCustomTheme(settings);
    }
    return getTheme(type);
  }

  static LinearGradient getGradient(ThemeType type, {AppSettings? settings}) {
    final theme =
        (type == ThemeType.custom && settings != null)
            ? buildCustomTheme(settings)
            : getTheme(type);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [theme.primaryColor, theme.secondaryColor, theme.backgroundColor],
      stops: const [0.0, 0.5, 1.0],
    );
  }
}

class LoveStoryTheme {
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color textColor;
  final Color cardColor;
  final Color accentColor;
  final bool isDark;

  const LoveStoryTheme({
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.textColor,
    required this.cardColor,
    required this.accentColor,
    this.isDark = true,
  });
}
