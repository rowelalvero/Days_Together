import 'package:flutter/material.dart';

import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/widgets/storage_image.dart';

/// Compact circular avatar.
///
/// Accepts the same avatar refs as [CachedAvatar]: a bare storage path, a
/// legacy public URL, a foreign URL, or a local file path.
class AppAvatar extends StatelessWidget {
  final String? path;
  final double radius;
  final Color? backgroundColor;
  final double? iconSize;
  final Color? iconColor;

  const AppAvatar({
    super.key,
    this.path,
    this.radius = 20,
    this.backgroundColor,
    this.iconSize,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey.withValues(alpha: 0.1),
      child: ClipOval(
        child: StorageImageBuilder(
          bucket: StorageBuckets.avatars,
          storageRef: path,
          builder: (context, image) {
            if (image == null) return _buildPlaceholder();
            return Image(
              image: image,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => _buildPlaceholder(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.person,
        size: iconSize ?? (radius * 1.2),
        color: iconColor ?? Colors.grey.withValues(alpha: 0.4),
      ),
    );
  }
}
