import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A reusable, cached avatar widget that handles:
/// - Remote HTTP URLs (cached on disk + memory via [CachedNetworkImage])
/// - Local file paths (via [FileImage])
/// - Null / empty / invalid paths (shows a placeholder icon)
///
/// This is the **single source of truth** for avatar display throughout the app.
/// All screens should use this instead of inline NetworkImage / CircleAvatar.
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
  /// - A full HTTP/HTTPS URL → loaded via CachedNetworkImage
  /// - A local file path → loaded via FileImage
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

  /// Returns `true` when [url] looks like a valid, loadable HTTP(S) URL.
  static bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        placeholderColor ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    final fallbackIconSize = iconSize ?? radius;

    final Widget avatar;

    if (_isValidUrl(path)) {
      // ── Remote URL ─────────────────────────────────────────────────────
      avatar = CachedNetworkImage(
        imageUrl: path!,
        imageBuilder: (_, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          child: SizedBox(
            width: fallbackIconSize * 0.6,
            height: fallbackIconSize * 0.6,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: bgColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        errorWidget: (_, url, error) {
          debugPrint('CachedAvatar: failed to load $url — $error');
          return CircleAvatar(
            radius: radius,
            backgroundColor: bgColor,
            child: Icon(
              Icons.person,
              size: fallbackIconSize,
              color: bgColor.withValues(alpha: 0.5),
            ),
          );
        },
      );
    } else if (path != null && path!.isNotEmpty) {
      // ── Local file path ────────────────────────────────────────────────
      // Use a FutureBuilder to avoid synchronous I/O in build().
      avatar = FutureBuilder<bool>(
        future: File(path!).exists(),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return CircleAvatar(
              radius: radius,
              backgroundColor: bgColor,
              backgroundImage: FileImage(File(path!)),
            );
          }
          return _placeholder(bgColor, fallbackIconSize);
        },
      );
    } else {
      // ── No path ────────────────────────────────────────────────────────
      avatar = _placeholder(bgColor, fallbackIconSize);
    }

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
