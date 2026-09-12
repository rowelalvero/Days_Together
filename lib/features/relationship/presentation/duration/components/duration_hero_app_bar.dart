import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The stretchy sliver app bar with the animated "TOGETHER FOR N Days"
/// hero counter atop [RelationshipDurationScreen]. Extracted from its
/// inline `build()` (Migration audit item 6).
class DurationHeroAppBar extends StatelessWidget {
  const DurationHeroAppBar({
    super.key,
    required this.totalDays,
    required this.startDate,
    required this.theme,
  });

  final int totalDays;
  final DateTime startDate;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: theme.textColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative circle
            Positioned(
              top: 40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      color: theme.accentColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'TOGETHER FOR',
                      style: AppTypography.cardCategory(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor.withValues(alpha: 0.6),
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: totalDays.toDouble()),
                  duration: const Duration(milliseconds: 1600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [theme.accentColor, Colors.amberAccent],
                      ).createShader(bounds),
                      child: Text(
                        NumberFormat('#,###').format(value.toInt()),
                        style: AppTypography.display(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
                Text(
                  'Days',
                  style: AppTypography.cormorant(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor.withValues(alpha: 0.8),
                  ).copyWith(letterSpacing: 1.0),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.textColor.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Since ${DateFormat('MMMM dd, yyyy').format(startDate)}',
                    style: AppTypography.bodyMono(
                      fontSize: 11,
                      color: theme.textColor.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
