import 'dart:io';

import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The tappable avatar-photo circle on [AvatarCreationScreen]. Extracted
/// from its inline `build()` (Migration audit item 6) -- the picked-photo
/// path and the pick flow itself stay on the screen's State.
class AvatarPickerCircle extends StatelessWidget {
  const AvatarPickerCircle({
    super.key,
    required this.avatarPath,
    required this.onTap,
    required this.theme,
  });

  final String? avatarPath;
  final VoidCallback onTap;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarPath != null && File(avatarPath!).existsSync();

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.textColor.withValues(alpha: 0.05),
            border: Border.all(
              color: theme.accentColor.withValues(alpha: 0.3),
              width: 3,
            ),
            image: hasAvatar
                ? DecorationImage(
                    image: FileImage(File(avatarPath!)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: hasAvatar
              ? null
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_rounded,
                      color: theme.accentColor,
                      size: 32,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add Photo',
                      style: AppTypography.caption(
                        color: theme.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
