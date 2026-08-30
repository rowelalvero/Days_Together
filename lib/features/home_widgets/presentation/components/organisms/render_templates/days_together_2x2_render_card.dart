import 'package:flutter/material.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';

class DaysTogether2x2RenderCard extends StatelessWidget {
  final LoveStoryTheme theme;
  final HomeWidgetConfig config;
  final String durationText;
  final String? milestoneText;

  const DaysTogether2x2RenderCard({
    super.key,
    required this.theme,
    required this.config,
    required this.durationText,
    this.milestoneText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: theme.accentColor.withValues(alpha: 0.35),
          width: 2.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primaryColor.withValues(alpha: 0.85),
            theme.secondaryColor.withValues(alpha: 0.95),
            theme.backgroundColor,
          ],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  config.customTitle,
                  style: TextStyle(
                    color: theme.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.favorite_rounded, color: theme.accentColor, size: 20),
            ],
          ),
          Center(
            child: Text(
              durationText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.w900,
                fontSize: 26,
                height: 1.15,
              ),
            ),
          ),
          if (config.showMilestone && milestoneText != null && milestoneText!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.accentColor.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: Text(
                  milestoneText!,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
