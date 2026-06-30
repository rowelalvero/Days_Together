import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/screens/love_story_screen.dart';
import 'package:provider/provider.dart';
import 'package:days_together/services/permission_service.dart';

class AvatarCreationScreen extends StatefulWidget {
  const AvatarCreationScreen({super.key});

  @override
  State<AvatarCreationScreen> createState() => _AvatarCreationScreenState();
}

class _AvatarCreationScreenState extends State<AvatarCreationScreen> {
  final TextEditingController _yourNameController = TextEditingController();
  String? _avatarPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<RelationshipProvider>();
    _yourNameController.text = provider.yourName ?? '';
  }

  @override
  void dispose() {
    _yourNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
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
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
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
                // Avatar Picker
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
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
                        image: _avatarPath != null && File(_avatarPath!).existsSync()
                            ? DecorationImage(
                                image: FileImage(File(_avatarPath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _avatarPath == null || !File(_avatarPath!).existsSync()
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_rounded,
                                    color: theme.accentColor, size: 32),
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
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                _buildNameField(
                  label: 'Your Name',
                  controller: _yourNameController,
                  hint: 'Enter your name',
                  theme: theme,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _completeSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Complete Setup',
                            style: AppTypography.button(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required dynamic theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.caption(
            color: theme.textColor.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ).copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: AppTypography.body(color: theme.textColor, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.body(color: theme.textColor.withValues(alpha: 0.3)),
            filled: true,
            fillColor: theme.textColor.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.accentColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAvatar() async {
    final hasPermission = await PermissionService().requestPhotosPermission(context);
    if (!hasPermission) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    final directory = await getApplicationDocumentsDirectory();
    final newPath = '${directory.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy(newPath);
    setState(() => _avatarPath = newPath);
  }

  Future<void> _completeSetup() async {
    if (_yourNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please share your name to complete your profile.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<RelationshipProvider>();
    await provider.setYourName(
      _yourNameController.text.trim(),
    );
    if (_avatarPath != null) {
      await provider.setAvatars(yourPath: _avatarPath);
    }
    await provider.completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoveStoryScreen()),
      (route) => false,
    );
  }
}
