import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';

/// The hairline between rows inside [NotificationSettingsScreen]'s cards.
///
/// Replaces the bare `Divider(height: 1)` those cards used to repeat,
/// which drew Material's own divider color and so ignored the active
/// [LoveStoryTheme] entirely -- visible as a too-dark line on this app's
/// light themes.
class NotificationCardDivider extends StatelessWidget {
  const NotificationCardDivider({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      endIndent: 16,
      color: theme.textColor.withValues(alpha: 0.06),
    );
  }
}
