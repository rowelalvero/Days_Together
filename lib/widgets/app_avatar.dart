import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    final bool isNetwork = path != null && path!.startsWith('http');
    final bool isLocal = path != null && !isNetwork && path!.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey.withValues(alpha: 0.1),
      child: ClipOval(
        child: _buildImage(context, isNetwork, isLocal),
      ),
    );
  }

  Widget _buildImage(BuildContext context, bool isNetwork, bool isLocal) {
    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: path!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) {
          debugPrint('AppAvatar Error: $error for URL: $url');
          return _buildPlaceholder();
        },
      );
    } else if (isLocal) {
      final file = File(path!);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        );
      }
    }
    return _buildPlaceholder();
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
