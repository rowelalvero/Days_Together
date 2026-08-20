import 'package:flutter/material.dart';

import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/widgets/storage_image.dart';

/// A reusable, cached avatar widget that handles:
/// - Storage refs (bare object paths, signed on demand and disk-cached)
/// - Legacy public URLs and foreign URLs (e.g. Google OAuth avatars)
/// - Local file paths (an upload that has not synced yet)
/// - Null / empty / unresolvable refs (shows a placeholder icon)
///
/// This is the **single source of truth** for avatar display throughout the app.
/// All screens should use this instead of an inline NetworkImage / CircleAvatar.
class CachedAvatar extends StatelessWidget {
  const CachedAvatar({
    super.key,
    required this.path,
    this.radius = 30,
    this.placeholderColor,
    this.borderColor,
    this.borderWidth = 0,
    this.iconSize,
  });

  /// The avatar source. Can be:
  /// - A bare storage path (`couples/{id}/avatars/…`) → signed, then cached
  /// - A legacy public URL → path extracted, then signed
  /// - A foreign URL (Google OAuth) → loaded directly
  /// - A local file path → loaded via [FileImage]
  /// - null or empty → shows placeholder icon
  final String? path;

  /// Radius of the circle avatar.
  final double radius;

  /// Background colour of the placeholder. Falls back to the theme's surface tint.
  final Color? placeholderColor;

  /// Optional decorative border colour around the avatar.
  final Color? borderColor;

  /// Width of the decorative border. 0 = no border.
  final double borderWidth;

  /// Size of the fallback person icon. Defaults to [radius].
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        placeholderColor ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    final fallbackIconSize = iconSize ?? radius;

    final Widget avatar = StorageImageBuilder(
      bucket: StorageBuckets.avatars,
      storageRef: path,
      builder: (context, image) {
        if (image == null) return _placeholder(bgColor, fallbackIconSize);
        return CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          backgroundImage: image,
        );
      },
    );

    // Wrap with decorative border if requested.
    if (borderWidth > 0 && borderColor != null) {
      return Container(
        padding: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: borderWidth),
        ),
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _placeholder(Color bgColor, double size) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Icon(
        Icons.person,
        size: size,
        color: bgColor.withValues(alpha: 0.5),
      ),
    );
  }
}
