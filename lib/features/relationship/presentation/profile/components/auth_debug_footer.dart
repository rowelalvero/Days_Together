import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/relationship/session_state.dart';

/// The faint "UID: ... • CID: ..." debug line at the bottom of
/// [RelationshipProfileScreen]. Extracted from its `_buildAuthDebugInfo`
/// (Migration audit item 6).
class AuthDebugFooter extends StatelessWidget {
  const AuthDebugFooter({
    super.key,
    required this.sessionState,
    required this.theme,
  });

  final SessionState sessionState;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: 0.3,
        child: Text(
          'UID: ${sessionState.userId?.substring(0, 8) ?? "None"} • CID: ${sessionState.coupleId?.substring(0, 8) ?? "None"}',
          style: AppTypography.captionMono(
            fontSize: 10,
            color: theme.textColor,
          ),
        ),
      ),
    );
  }
}
