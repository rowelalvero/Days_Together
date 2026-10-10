// ThemeContrast math and the custom theme's readability guard: a custom
// theme whose requested Dark/Light ink would be unreadable on its own
// gradient falls back to the opposite ink.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/models/app_settings.dart';

void main() {
  group('ThemeContrast', () {
    test('ratio matches the WCAG extremes', () {
      expect(
        ThemeContrast.ratio(Colors.black, Colors.white),
        closeTo(21.0, 0.01),
      );
      expect(ThemeContrast.ratio(Colors.white, Colors.white), 1.0);
    });

    test('onColor picks dark ink on pastels and white on deep colors', () {
      expect(
        ThemeContrast.onColor(const Color(0xFFADE8F4)),
        ThemeContrast.darkInk,
      );
      expect(
        ThemeContrast.onColor(const Color(0xFF10122B)),
        ThemeContrast.lightInk,
      );
    });

    test('onAccentColor follows the accent, not the theme mode', () {
      // Azure Liquid is a dark theme with a pastel accent.
      final azure = ThemeManager.getTheme(ThemeType.liquidGlass);
      expect(azure.isDark, isTrue);
      expect(azure.onAccentColor, ThemeContrast.darkInk);
      // Lovely Off-White is a light theme whose deep pink accent takes white.
      final offWhite = ThemeManager.getTheme(ThemeType.offWhite);
      expect(offWhite.isDark, isFalse);
      expect(offWhite.onAccentColor, ThemeContrast.lightInk);
    });
  });

  group('ThemeManager.buildCustomTheme', () {
    test('keeps the requested ink when it is readable', () {
      final theme = ThemeManager.buildCustomTheme(
        AppSettings(
          customPrimaryColor: 0xFF10122B,
          customSecondaryColor: 0xFF1A1B41,
          customBackgroundColor: 0xFF0A0B1A,
          customIsDark: true,
        ),
      );
      expect(theme.isDark, isTrue);
      expect(theme.textColor, ThemeContrast.lightInk);
    });

    test('flips to dark ink when Dark mode is paired with pastels', () {
      final theme = ThemeManager.buildCustomTheme(
        AppSettings(
          customPrimaryColor: 0xFFFFC4D6,
          customSecondaryColor: 0xFFFFF0F5,
          customBackgroundColor: 0xFFFFF8FA,
          customIsDark: true,
        ),
      );
      expect(theme.isDark, isFalse);
      expect(theme.textColor, ThemeContrast.darkInk);
      expect(
        ThemeContrast.minRatio(theme.textColor, [
          theme.primaryColor,
          theme.secondaryColor,
          theme.backgroundColor,
        ]),
        greaterThanOrEqualTo(ThemeContrast.minBodyText),
      );
    });

    test('flips to light ink when Light mode is paired with deep colors', () {
      final theme = ThemeManager.buildCustomTheme(
        AppSettings(
          customPrimaryColor: 0xFF10122B,
          customSecondaryColor: 0xFF2C003E,
          customBackgroundColor: 0xFF03045E,
          customIsDark: false,
        ),
      );
      expect(theme.isDark, isTrue);
      expect(theme.textColor, ThemeContrast.lightInk);
    });

    test('leaves a mixed gradient on the requested ink when flipping is '
        'no better', () {
      // The default custom colors: bright pink into deep purple. White is
      // weak on the pink, but dark ink is far worse on the purple.
      final theme = ThemeManager.buildCustomTheme(AppSettings());
      expect(theme.isDark, isTrue);
      expect(theme.textColor, ThemeContrast.lightInk);
    });
  });
}
