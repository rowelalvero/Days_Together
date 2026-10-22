import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// Live readability check for the custom theme: a text sample on each of the
/// three gradient stops with its WCAG contrast ratio, plus a one-line verdict
/// for the weakest one. Says so when the requested Dark/Light mode was
/// overridden to keep text readable (see `ThemeManager.buildCustomTheme`).
class ReadabilityPreview extends StatelessWidget {
  const ReadabilityPreview({
    super.key,
    required this.customTheme,
    required this.requestedDark,
    required this.parentTheme,
  });

  /// The resolved custom theme, i.e. with the text ink actually used.
  final LoveStoryTheme customTheme;

  /// The mode the user picked with the Dark/Light toggle.
  final bool requestedDark;

  /// The theme the designer itself is drawn in.
  final LoveStoryTheme parentTheme;

  @override
  Widget build(BuildContext context) {
    final ink = customTheme.textColor;
    final stops = [
      ('Primary', customTheme.primaryColor),
      ('Secondary', customTheme.secondaryColor),
      ('Background', customTheme.backgroundColor),
    ];
    final ratios = [
      for (final (_, color) in stops) ThemeContrast.ratio(ink, color),
    ];
    var weakest = 0;
    for (var i = 1; i < ratios.length; i++) {
      if (ratios[i] < ratios[weakest]) weakest = i;
    }
    final worst = ratios[weakest];
    final weakestName = stops[weakest].$1;

    final semantic = parentTheme.semantic;
    final (
      Color tone,
      IconData icon,
      String verdict,
    ) = worst >= ThemeContrast.minBodyText
        ? (semantic.success, Icons.check_circle_rounded, 'Easy to read')
        : worst >= ThemeContrast.minLargeText
        ? (
            semantic.warning,
            Icons.info_rounded,
            'Headings are fine, small text is faint on $weakestName',
          )
        : (
            semantic.error,
            Icons.warning_rounded,
            'Text is hard to read on $weakestName. Try a darker or lighter '
                '${weakestName.toLowerCase()} color.',
          );
    final overridden = customTheme.isDark != requestedDark;
    final usedInk = customTheme.isDark ? 'light' : 'dark';
    final requestedMode = requestedDark ? 'Dark' : 'Light';

    return GlassContainer(
      borderRadius: 18,
      opacity: 0.06,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < stops.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _Sample(
                    label: stops[i].$1,
                    surface: stops[i].$2,
                    ink: ink,
                    ratio: ratios[i],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: tone),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    verdict,
                    style: AppTypography.caption(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: parentTheme.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (overridden) ...[
            const SizedBox(height: 6),
            Text(
              'Using $usedInk text: $requestedMode mode text would be '
              'unreadable on these colors.',
              style: AppTypography.caption(
                fontSize: 12,
                color: parentTheme.textColor.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Sample extends StatelessWidget {
  const _Sample({
    required this.label,
    required this.surface,
    required this.ink,
    required this.ratio,
  });

  final String label;
  final Color surface;
  final Color ink;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: contrast ${ratio.toStringAsFixed(1)} to 1',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ink.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              'Aa',
              style: AppTypography.heading(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${ratio.toStringAsFixed(1)}:1',
              style: AppTypography.captionMono(fontSize: 11, color: ink),
            ),
          ],
        ),
      ),
    );
  }
}
