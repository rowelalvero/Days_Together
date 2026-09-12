import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/widgets/cached_avatar.dart';

/// One partner's avatar + name in [LiquidProfileCard]. Extracted from
/// [SettingsTab]'s `_buildMiniAvatar` (Migration audit item 6).
class MiniAvatar extends StatelessWidget {
  const MiniAvatar({
    super.key,
    required this.path,
    required this.name,
    required this.theme,
  });

  final String? path;
  final String name;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CachedAvatar(
              path: path,
              radius: 30,
              backgroundColor: theme.textColor.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              color: theme.textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
