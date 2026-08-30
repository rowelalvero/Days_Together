import 'package:flutter/material.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';

class DaysTogether4x2RenderCard extends StatelessWidget {
  final LoveStoryTheme theme;
  final HomeWidgetConfig config;
  final String daysCount;
  final String timeText;
  final String? milestoneText;
  final String partner1Name;
  final String partner2Name;

  const DaysTogether4x2RenderCard({
    super.key,
    required this.theme,
    required this.config,
    required this.daysCount,
    required this.timeText,
    this.milestoneText,
    required this.partner1Name,
    required this.partner2Name,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 640,
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
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: Row(
        children: [
          // Left column: Avatars and names
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    _AvatarCircle(name: partner1Name, theme: theme),
                    Transform.translate(
                      offset: const Offset(-8, 0),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.primaryColor,
                        ),
                        child: Icon(Icons.favorite_rounded, color: theme.accentColor, size: 16),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(-16, 0),
                      child: _AvatarCircle(name: partner2Name, theme: theme),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  config.customTitle,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (milestoneText != null && config.showMilestone)
                  Text(
                    milestoneText!,
                    style: TextStyle(
                      color: theme.accentColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            width: 1.5,
            height: 180,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(width: 24),
          // Right column: Big days and timer
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      daysCount,
                      style: TextStyle(
                        color: theme.textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 38,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DAYS',
                      style: TextStyle(
                        color: theme.accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                if (config.showSeconds) ...[
                  const SizedBox(height: 6),
                  Text(
                    timeText,
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String name;
  final LoveStoryTheme theme;

  const _AvatarCircle({required this.name, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.secondaryColor,
        border: Border.all(color: theme.accentColor, width: 2),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '💖',
          style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
