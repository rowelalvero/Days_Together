import 'package:flutter/material.dart' show LinearGradient;
import 'package:days_together/models/app_settings.dart';
import 'package:days_together/themes/theme_manager.dart';

/// State for `ThemeController` (Item 3 gap-fix, Phase 2 -- front 3 of the
/// architecture migration's `provider`-removal item). A direct Riverpod
/// port of `ThemeProvider`'s two fields (`_currentTheme`/`_settings`);
/// `currentLoveTheme`/`currentGradient` stay as derived getters computed via
/// `ThemeManager`, exactly as `ThemeProvider` computes them today, rather
/// than being stored.
///
/// Deliberately has no `==`/`hashCode` override: `AppSettings` itself has
/// none (identity equality only), so a whole-state comparison would only
/// ever catch the literal-same-instance case, giving false confidence.
/// `ThemeController`'s mutators instead replicate `ThemeProvider`'s original
/// field-specific no-op guards directly, the same way the original does.
class ThemeState {
  final ThemeType currentTheme;
  final AppSettings settings;

  ThemeState({
    this.currentTheme = ThemeType.offWhite,
    AppSettings? settings,
  }) : settings = settings ?? AppSettings();

  LoveStoryTheme get currentLoveTheme =>
      ThemeManager.resolveTheme(currentTheme, settings);

  LinearGradient get currentGradient =>
      ThemeManager.getGradient(currentTheme, settings: settings);

  ThemeState copyWith({
    ThemeType? currentTheme,
    AppSettings? settings,
  }) {
    return ThemeState(
      currentTheme: currentTheme ?? this.currentTheme,
      settings: settings ?? this.settings,
    );
  }
}
