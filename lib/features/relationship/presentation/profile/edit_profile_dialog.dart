import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget, WidgetRef;

import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/services/permission_service.dart';
import 'package:days_together/shared/cached_avatar.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:image_picker/image_picker.dart';

/// The bottom sheet for editing your (and, if paired, your partner's)
/// display name and avatar. Extracted out of
/// `RelationshipProfileScreen._editProfileDialog` (per
/// `god-file-decomposition.md` item 5).
class EditProfileDialog extends ConsumerStatefulWidget {
  const EditProfileDialog({super.key, required this.theme});

  final LoveStoryTheme theme;

  static void show(BuildContext context, LoveStoryTheme theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (context) => EditProfileDialog(theme: theme),
    );
  }

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  late final TextEditingController _yourController;
  late final TextEditingController _partnerController;

  @override
  void initState() {
    super.initState();
    // One-shot seeds for mutable text fields, so `read` rather than `watch`:
    // re-reading on a later rebuild would overwrite what the user has typed.
    final profile = ref.read(profileControllerProvider);
    _yourController = TextEditingController(text: profile.yourName);
    _partnerController = TextEditingController(text: profile.partnerName);
  }

  @override
  void dispose() {
    _yourController.dispose();
    _partnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    // Watched, not a prop-drilled `CoupleSession` handle: the avatar row
    // reads `yourAvatarPath`/`partnerAvatarPath`, and picking a new image
    // previously left the old one on screen because nothing marked this
    // dialog dirty after `setAvatars` resolved.
    final profile = ref.watch(profileControllerProvider);
    final partnerJoined = ref.watch(sessionControllerProvider).partnerId != null;

    return GlassContainer(
      borderRadius: 32,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 30,
        top: 30,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit Your Profiles',
              style: AppTypography.heading(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 32),
            _buildAvatarRow(context, profile.yourAvatarPath, theme, true),
            const SizedBox(height: 20),
            _buildNameField(_yourController, 'Your Name', theme),
            if (partnerJoined) ...[
              const SizedBox(height: 32),
              _buildAvatarRow(context, profile.partnerAvatarPath, theme, false),
              const SizedBox(height: 20),
              _buildNameField(_partnerController, "Partner's Name", theme),
            ],
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Discard Changes',
                      style: AppTypography.body(
                        color: theme.textColor.withValues(alpha: 0.54),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final controller = ref.read(profileControllerProvider.notifier);
                      if (partnerJoined) {
                        await controller.setNames(
                          _yourController.text.trim(),
                          _partnerController.text.trim(),
                        );
                      } else {
                        await controller.setYourName(_yourController.text.trim());
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save Profile Details',
                      style: AppTypography.body(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarRow(
    BuildContext context,
    String? path,
    LoveStoryTheme theme,
    bool isYou,
  ) {
    return GestureDetector(
      onTap: () => _pickAvatar(context, ref, isYou),
      child: Stack(
        children: [
          CachedAvatar(
            path: path,
            radius: 40,
            backgroundColor: theme.textColor.withValues(alpha: 0.1),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.accentColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(
    TextEditingController controller,
    String label,
    LoveStoryTheme theme,
  ) {
    return GlassContainer(
      opacity: 0.05,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        style: AppTypography.body(color: theme.textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTypography.caption(
            color: theme.textColor.withValues(alpha: 0.3),
            fontSize: 12,
          ),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Future<void> _pickAvatar(
    BuildContext context,
    WidgetRef ref,
    bool isYou,
  ) async {
    final hasPermission = await PermissionService().requestPhotosPermission(
      context,
    );
    if (!hasPermission) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      try {
        final controller = ref.read(profileControllerProvider.notifier);
        if (isYou) {
          await controller.setAvatars(yourPath: pickedFile.path);
        } else {
          await controller.setAvatars(partnerPath: pickedFile.path);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile image updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update profile image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
