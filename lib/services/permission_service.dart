import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:days_together/widgets/glass_permission_dialog.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  Future<bool> requestCameraPermission(BuildContext context) async {
    return _handlePermissionRequest(
      context,
      Permission.camera,
      'Camera Permission Required',
      'We need camera access to capture love notes and drawings to share with your partner.',
      Icons.camera_alt_rounded,
    );
  }

  Future<bool> requestPhotosPermission(BuildContext context) async {
    Permission permission = Permission.photos;

    if (Platform.isAndroid) {
      final sdkInt = _getAndroidSdkInt();
      if (sdkInt < 33) {
        permission = Permission.storage;
      }
    }

    return _handlePermissionRequest(
      context,
      permission,
      'Storage Access Required',
      'We need access to your photos to choose memory cards and backgrounds.',
      Icons.photo_library_rounded,
    );
  }

  int _getAndroidSdkInt() {
    try {
      final versionString = Platform.operatingSystemVersion;
      final apiMatch = RegExp(r'API\s+(\d+)').firstMatch(versionString);
      if (apiMatch != null) {
        return int.parse(apiMatch.group(1)!);
      }
    } catch (_) {}
    return 0;
  }

  Future<bool> requestNotificationPermission(BuildContext context) async {
    return _handlePermissionRequest(
      context,
      Permission.notification,
      'Notifications Required',
      'We need notification permissions to keep you in sync with your partner\'s mood and notes.',
      Icons.notifications_active_rounded,
    );
  }

  Future<bool> _handlePermissionRequest(
    BuildContext context,
    Permission permission,
    String title,
    String rationale,
    IconData icon,
  ) async {
    final status = await permission.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => GlassPermissionDialog(
          title: title,
          rationale: rationale,
          icon: icon,
        ),
      );
      return false;
    }

    final result = await permission.request();
    if (result.isGranted) {
      return true;
    }

    if (result.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => GlassPermissionDialog(
          title: title,
          rationale: rationale,
          icon: icon,
        ),
      );
    }

    return false;
  }
}
