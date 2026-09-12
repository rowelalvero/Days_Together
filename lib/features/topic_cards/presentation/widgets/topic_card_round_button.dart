import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';

/// One of the three circular deck controls (previous/shuffle/next) at the
/// bottom of [TopicCardsScreen]. Extracted from that screen's
/// `_buildRoundButton` (Migration audit item 6) -- purely a render of its
/// constructor arguments, no state of its own.
class TopicCardRoundButton extends StatelessWidget {
  const TopicCardRoundButton({
    super.key,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.theme,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final LoveStoryTheme theme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.textColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 26),
      ),
    );
  }
}
