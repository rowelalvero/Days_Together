import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The back button and title row at the top of [RelationshipProfileScreen].
/// Extracted from its `_buildAppBar` (Migration audit item 6).
class ProfileAppBar extends StatelessWidget {
  const ProfileAppBar({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: theme.textColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Relationship Profile',
            style: AppTypography.cormorant(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
