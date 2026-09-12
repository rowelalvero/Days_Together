import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/authentication/presentation/widgets/avatar_picker_circle.dart';
import 'package:days_together/features/authentication/presentation/widgets/complete_setup_button.dart';
import 'package:days_together/features/authentication/presentation/widgets/name_field.dart';
import 'package:days_together/core/permissions/permission_service.dart';

/// Onboarding screen where a new user picks an avatar and enters their
/// name.
///
/// Its inline avatar-picker circle, name field, and submit button were
/// extracted into widgets under `presentation/widgets/` (Migration audit
/// item 6) -- this class still owns the picked-avatar path, the name
/// controller, the saving flag, and the setup-completion flow.
class AvatarCreationScreen extends ConsumerStatefulWidget {
  const AvatarCreationScreen({super.key});

  @override
  ConsumerState<AvatarCreationScreen> createState() =>
      _AvatarCreationScreenState();
}

class _AvatarCreationScreenState extends ConsumerState<AvatarCreationScreen> {
  final TextEditingController _yourNameController = TextEditingController();
  String? _avatarPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _yourNameController.text =
        ref.read(profileControllerProvider).yourName ?? '';
  }

  @override
  void dispose() {
    _yourNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Let's add a face\nto your name.",
                  style: AppTypography.cormorant(
                    fontSize: 36,
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This is how your partner will see you in your shared space.',
                  style: AppTypography.spectral(
                    fontSize: 16,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 40),
                AvatarPickerCircle(
                  avatarPath: _avatarPath,
                  onTap: _pickAvatar,
                  theme: theme,
                ),
                const SizedBox(height: 40),
                NameField(
                  label: 'Your Name',
                  controller: _yourNameController,
                  hint: 'Enter your name',
                  theme: theme,
                ),
                const SizedBox(height: 48),
                CompleteSetupButton(
                  isSaving: _isSaving,
                  onPressed: _completeSetup,
                  theme: theme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final hasPermission = await PermissionService().requestPhotosPermission(
      context,
    );
    if (!mounted) return;
    if (!hasPermission) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;

    final directory = await getApplicationDocumentsDirectory();
    final newPath =
        '${directory.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy(newPath);
    if (!mounted) return;

    setState(() => _avatarPath = newPath);
  }

  Future<void> _completeSetup() async {
    if (_yourNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please share your name to complete your profile.'),
        ),
      );
      return;
    }

    try {
      setState(() => _isSaving = true);
      final profile = ref.read(profileControllerProvider.notifier);
      final session = ref.read(sessionControllerProvider.notifier);
      await profile.setYourName(_yourNameController.text.trim());
      if (_avatarPath != null) {
        // The avatar upload is encrypted with the couple photo key, which the
        // *joining* partner does not hold until the key exchange lands. Wait
        // briefly for it (this returns immediately once the key is present,
        // and never throws on timeout), then treat a failed upload as
        // non-fatal.
        await session.waitForCoupleKey();
        try {
          await profile.setAvatars(yourPath: _avatarPath);
        } catch (e) {
          // Onboarding must not be held hostage by a photo upload: letting
          // this propagate skipped completeOnboarding() below and stranded
          // the joining partner on this screen with no way forward. The
          // local path is already set, and StorageImage prefers it over
          // anything remote, so the avatar still displays on this device
          // while it syncs later.
          debugPrint('Avatar upload deferred during onboarding: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("We'll finish syncing your photo in a moment."),
              ),
            );
          }
        }
      }
      // No explicit navigation after this: completeOnboarding() flips
      // CoupleSession's stage to `ready`, which the router's single
      // redirect (app_router.dart) picks up via refreshListenable and
      // bounces to Routes.home automatically -- this was previously one of
      // ADR-007's four independent "is the user ready" restatements
      // (main.dart's old AppHome switch, notification_service.dart,
      // recover_relationship_screen.dart, and this screen), each hand-coded
      // separately; now there is exactly one.
      await session.completeOnboarding();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete setup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
