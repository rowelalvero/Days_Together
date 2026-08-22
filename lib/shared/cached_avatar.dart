import 'package:flutter/material.dart';

import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/shared/storage_image.dart';

/// A reusable, cached avatar widget that handles:
/// - Storage refs (bare object paths, signed on demand and disk-cached)
/// - Legacy public URLs and foreign URLs (e.g. Google OAuth avatars)
/// - Local file paths (an upload that has not synced yet)
/// - Null / empty / unresolvable refs (shows a placeholder icon)
///
/// This is the **single source of truth** for avatar display throughout the
/// app -- Phase 7b of the architecture migration merged this with the
/// formerly-separate `AppAvatar`, which duplicated the same job with a
/// slightly different parameter surface (`backgroundColor`/`iconColor`
/// instead of `placeholderColor`, no border support, and no `errorBuilder`
/// fallback if a resolved image failed to load). All screens should use
/// this instead of an inline NetworkImage / CircleAvatar.
class CachedAvatar extends StatelessWidget {
  const CachedAvatar({
    super.key,
    this.path,
    this.radius = 30,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.iconSize,
    this.iconColor,
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

  /// Background colour behind the image / placeholder icon. Falls back to
  /// the theme's surface tint.
  final Color? backgroundColor;

  /// Optional decorative border colour around the avatar.
  final Color? borderColor;

  /// Width of the decorative border. 0 = no border.
  final double borderWidth;

  /// Size of the fallback person icon. Defaults to [radius].
  final double? iconSize;

  /// Colour of the fallback person icon. Defaults to a tint of
  /// [backgroundColor].
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    final fallbackIconSize = iconSize ?? radius;

    final Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: ClipOval(
        child: StorageImageBuilder(
          bucket: StorageBuckets.avatars,
          storageRef: path,
          builder: (context, image) {
            if (image == null) return _placeholder(bgColor, fallbackIconSize);
            return Image(
              image: image,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => _placeholder(bgColor, fallbackIconSize),
            );
          },
        ),
      ),
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
    return Center(
      child: Icon(
        Icons.person,
        size: size,
        color: iconColor ?? bgColor.withValues(alpha: 0.5),
      ),
    );
  }
}
