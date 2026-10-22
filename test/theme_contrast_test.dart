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

  group('text tokens', () {
    // The surfaces text sits on: the page and a translucent card over it.
    List<Color> surfaces(LoveStoryTheme t) => [
      t.backgroundColor,
      Color.alphaBlend(t.cardColor, t.backgroundColor),
    ];
    double worst(Color ink, LoveStoryTheme t) => surfaces(t)
        .map((s) => ThemeContrast.ratio(Color.alphaBlend(ink, s), s))
        .reduce((a, b) => a < b ? a : b);

    final all = {
      for (final e in ThemeManager.themes.entries) e.key.name: e.value,
      'custom (default)': ThemeManager.buildCustomTheme(AppSettings()),
      'custom (light, pale accent)': ThemeManager.buildCustomTheme(
        AppSettings(
          customPrimaryColor: 0xFFFFF0F5,
          customSecondaryColor: 0xFFFFE4EC,
          customBackgroundColor: 0xFFFFF8FA,
          customAccentColor: 0xFFFFC4D6,
          customIsDark: false,
        ),
      ),
    };

    for (final MapEntry(key: name, value: theme) in all.entries) {
      test('$name: secondary and accent text meet 4.5:1 on page and card', () {
        expect(
          worst(theme.secondaryTextColor, theme),
          greaterThanOrEqualTo(ThemeContrast.minBodyText),
        );
        expect(
          worst(theme.accentTextColor, theme),
          greaterThanOrEqualTo(ThemeContrast.minBodyText),
        );
        // Still visibly secondary: never the full-strength text color.
        expect(theme.secondaryTextColor.a, lessThan(1.0));
      });
    }

    test('dark themes keep the 0.6 opacity they already read at', () {
      for (final type in [
        ThemeType.midnightRose,
        ThemeType.liquidGlass,
        ThemeType.deepPurple,
      ]) {
        final t = ThemeManager.getTheme(type);
        expect(t.secondaryTextColor.a, closeTo(0.6, 0.001), reason: type.name);
      }
    });

    test('an accent that already reads is left exactly as designed', () {
      final midnight = ThemeManager.getTheme(ThemeType.midnightRose);
      expect(midnight.accentTextColor, midnight.accentColor);
    });

    test('Lovely Off-White deepens its rose accent and secondary text', () {
      final t = ThemeManager.getTheme(ThemeType.offWhite);
      // Measured 3.3:1 as designed; the token must differ to reach 4.5.
      expect(worst(t.accentColor, t), lessThan(ThemeContrast.minBodyText));
      expect(t.accentTextColor, isNot(t.accentColor));
      expect(t.secondaryTextColor.a, greaterThan(0.6));
    });

    test('dimmed and readable fall back to full strength when nothing less '
        'qualifies', () {
      const grey = Color(0xFF777777);
      expect(ThemeContrast.dimmed(grey, const [Color(0xFF888888)]).a, 1.0);
      const surface = [Color(0xFF888888)];
      // A target that never reaches 4.5:1 itself is returned as-is...
      const target = Color(0xFF666666);
      expect(ThemeContrast.readable(grey, surface, toward: target), target);
      // ...otherwise it stops at the first mix that qualifies, short of the
      // target, keeping as much of the original color as it can.
      final mixed = ThemeContrast.readable(grey, surface, toward: Colors.black);
      expect(
        ThemeContrast.ratio(mixed, surface.single),
        greaterThanOrEqualTo(ThemeContrast.minBodyText),
      );
      expect(mixed, isNot(Colors.black));
    });
  });
}
