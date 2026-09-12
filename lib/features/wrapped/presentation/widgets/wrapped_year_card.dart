import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

const List<Color> _yearColors = [
  Color(0xFFF43F5E),
  Color(0xFF7C3AED),
  Color(0xFF06B6D4),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
];

const List<String> _yearEmojis = ['❤️', '💜', '💙', '💛', '💚'];

/// One archived-year row on [WrappedArchiveScreen]'s list. Extracted from
/// its `_buildYearCard` method (Migration audit item 6) -- [index] picks
/// the card's color/emoji from a fixed palette and staggers its
/// entrance animation.
///
/// The per-year color stays Wrapped's own (it is the feature's signature,
/// and reads as a tint at these alphas on light and dark themes alike),
/// but the type is drawn in [theme]'s text color rather than the hardcoded
/// white it used while this screen painted itself dark.
class WrappedYearCard extends StatelessWidget {
  const WrappedYearCard({
    super.key,
    required this.year,
    required this.index,
    required this.theme,
    required this.onTap,
  });

  final int year;
  final int index;
  final LoveStoryTheme theme;
  final VoidCallback onTap;

  Color get _color => _yearColors[index % _yearColors.length];
  String get _emoji => _yearEmojis[index % _yearEmojis.length];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - v)),
        child: Opacity(opacity: v, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GestureDetector(
          onTap: onTap,
          child: GlassContainer(
            borderRadius: 20,
            opacity: 0.03,
            padding: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _color.withValues(alpha: 0.15),
                    _color.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _color.withValues(alpha: 0.15),
                      border: Border.all(
                        color: _color.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(_emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wrapped $year',
                          style: AppTypography.heading(
                            fontSize: 20,
                            color: theme.textColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your year in review',
                          style: AppTypography.body(
                            fontSize: 13,
                            color: theme.textColor.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.play_arrow_rounded,
                    color: theme.textColor.withValues(alpha: 0.4),
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
