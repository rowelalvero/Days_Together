import 'package:days_together/models/app_settings.dart';
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

/// Spacing scale (Phase 7 of the architecture migration, design-system.md).
@immutable
class LoveStorySpacing {
  final double xs, sm, md, lg, xl, xxl;

  const LoveStorySpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
    this.xxl = 48,
  });
}

/// Corner-radius scale (Phase 7, design-system.md). `pill` is deliberately
/// large enough to fully round any realistic control height, not a fixed
/// "half of some specific height" value.
@immutable
class LoveStoryRadii {
  final double sm, md, lg, pill;

  const LoveStoryRadii({
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.pill = 999,
  });
}

/// Elevation scale (Phase 7, design-system.md) -- shadow "depth" steps, not
/// tied to Material's own `elevation` property specifically.
@immutable
class LoveStoryElevation {
  final double flat, low, medium, high;

  const LoveStoryElevation({
    this.flat = 0,
    this.low = 2,
    this.medium = 4,
    this.high = 8,
  });
}

/// Animation duration/curve scale (Phase 7, design-system.md).
@immutable
class LoveStoryMotion {
  final Duration fast, normal, slow;
  final Curve standard, emphasized;

  const LoveStoryMotion({
    this.fast = const Duration(milliseconds: 150),
    this.normal = const Duration(milliseconds: 300),
    this.slow = const Duration(milliseconds: 500),
    this.standard = Curves.easeInOut,
    this.emphasized = Curves.easeOutCubic,
  });
}

/// State colors (Phase 7, design-system.md) -- deliberately separate from
/// [LoveStoryTheme]'s 6 aesthetic colors (`primaryColor` etc.), which express
/// the app's romantic visual identity per selected theme and must not be
/// conflated with colors that mean something regardless of which theme is
/// active (a destructive-action confirmation, a sync error, a success
/// toast). A theme whose accent color happens to be red-adjacent must not
/// accidentally make error states unreadable or success states look like
/// warnings.
@immutable
class LoveStorySemantic {
  final Color success, warning, error, info;

  const LoveStorySemantic({
    this.success = const Color(0xFF10B981),
    this.warning = const Color(0xFFF59E0B),
    this.error = const Color(0xFFEF4444),
    this.info = const Color(0xFF3B82F6),
  });
}

/// The app's design-token bundle (Phase 7 of the architecture migration).
/// A `ThemeExtension<LoveStoryTheme>` -- Flutter's own mechanism for
/// app-specific theme tokens -- so `Theme.of(context).extension<LoveStoryTheme>()`
/// works as a typed accessor alongside the existing `ThemeController`-based
/// `ref.watch(themeControllerProvider).currentLoveTheme` access pattern; the
/// two compose (see design-system.md's "Material 3 / Google Fonts
/// configuration" section) rather than one replacing the other in this phase.
///
/// The original 8 fields (`name` through `isDark`) are unchanged -- this is
/// a pure token *addition*, not a redesign; no color, gradient, or typeface
/// choice changes what the app looks like today.
@immutable
class LoveStoryTheme extends ThemeExtension<LoveStoryTheme> {
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color textColor;
  final Color cardColor;
  final Color accentColor;
  final bool isDark;
  final LoveStorySpacing spacing;
  final LoveStoryRadii radii;
  final LoveStoryElevation elevation;
  final LoveStoryMotion motion;
  final LoveStorySemantic semantic;

  const LoveStoryTheme({
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.textColor,
    required this.cardColor,
    required this.accentColor,
    this.isDark = true,
    this.spacing = const LoveStorySpacing(),
    this.radii = const LoveStoryRadii(),
    this.elevation = const LoveStoryElevation(),
    this.motion = const LoveStoryMotion(),
    this.semantic = const LoveStorySemantic(),
  });

  @override
  LoveStoryTheme copyWith({
    String? name,
    Color? primaryColor,
    Color? secondaryColor,
    Color? backgroundColor,
    Color? textColor,
    Color? cardColor,
    Color? accentColor,
    bool? isDark,
    LoveStorySpacing? spacing,
    LoveStoryRadii? radii,
    LoveStoryElevation? elevation,
    LoveStoryMotion? motion,
    LoveStorySemantic? semantic,
  }) {
    return LoveStoryTheme(
      name: name ?? this.name,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      cardColor: cardColor ?? this.cardColor,
      accentColor: accentColor ?? this.accentColor,
      isDark: isDark ?? this.isDark,
      spacing: spacing ?? this.spacing,
      radii: radii ?? this.radii,
      elevation: elevation ?? this.elevation,
      motion: motion ?? this.motion,
      semantic: semantic ?? this.semantic,
    );
  }

  @override
  LoveStoryTheme lerp(ThemeExtension<LoveStoryTheme>? other, double t) {
    if (other is! LoveStoryTheme) return this;
    // The 6 aesthetic colors and the 4 semantic colors interpolate smoothly
    // (this is what ThemeExtension.lerp exists for -- smooth theme-switch
    // transitions). The non-color token groups (spacing/radii/elevation/
    // motion) and the discrete fields (name/isDark) don't have a meaningful
    // interpolated value, so they switch at the midpoint instead, matching
    // how Flutter's own ThemeData.lerp treats non-interpolable fields.
    return LoveStoryTheme(
      name: t < 0.5 ? name : other.name,
      primaryColor: Color.lerp(primaryColor, other.primaryColor, t)!,
      secondaryColor: Color.lerp(secondaryColor, other.secondaryColor, t)!,
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      textColor: Color.lerp(textColor, other.textColor, t)!,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
      spacing: t < 0.5 ? spacing : other.spacing,
      radii: t < 0.5 ? radii : other.radii,
      elevation: t < 0.5 ? elevation : other.elevation,
      motion: t < 0.5 ? motion : other.motion,
      semantic: LoveStorySemantic(
        success: Color.lerp(semantic.success, other.semantic.success, t)!,
        warning: Color.lerp(semantic.warning, other.semantic.warning, t)!,
        error: Color.lerp(semantic.error, other.semantic.error, t)!,
        info: Color.lerp(semantic.info, other.semantic.info, t)!,
      ),
    );
  }
}
