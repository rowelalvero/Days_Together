import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:image_picker/image_picker.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/widgets/theme_selector.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/screens/onboarding/welcome_screen.dart';
import 'package:days_together/screens/settings/relationship_profile_screen.dart';
import 'package:days_together/services/permission_service.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Future<void> _pickAvatar(BuildContext context, RelationshipProvider rp, bool isYou) async {
    final hasPermission = await PermissionService().requestPhotosPermission(context);
    if (!hasPermission) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      if (isYou) {
        await rp.setAvatars(yourPath: pickedFile.path);
      } else {
        await rp.setAvatars(partnerPath: pickedFile.path);
      }
    }
  }

  void _editProfileDialog(BuildContext context, RelationshipProvider rp, dynamic theme) {
    final yourController = TextEditingController(text: rp.yourName);
    final partnerController = TextEditingController(text: rp.partnerName);
    final partnerJoined = rp.partnerId != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassContainer(
          borderRadius: 32,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 30,
            top: 30,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Personalize Your Story',
                style: AppTypography.sectionHeader(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 32),
              _buildAvatarRow(context, rp, theme, true),
              const SizedBox(height: 20),
              _buildNameField(yourController, 'Your Name', theme),
              if (partnerJoined) ...[
                const SizedBox(height: 32),
                _buildAvatarRow(context, rp, theme, false),
                const SizedBox(height: 20),
                _buildNameField(partnerController, "Partner's Name", theme),
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
                        if (partnerJoined) {
                          await rp.setNames(yourController.text.trim(), partnerController.text.trim());
                        } else {
                          await rp.setYourName(yourController.text.trim());
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Save Profile Details',
                        style: AppTypography.body(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarRow(BuildContext context, RelationshipProvider rp, dynamic theme, bool isYou) {
    final path = isYou ? rp.yourAvatarPath : rp.partnerAvatarPath;
    return GestureDetector(
      onTap: () => _pickAvatar(context, rp, isYou),
      child: Stack(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white10,
            backgroundImage: path != null
                ? (path.startsWith('http')
                    ? NetworkImage(path) as ImageProvider
                    : (File(path).existsSync()
                        ? FileImage(File(path))
                        : null))
                : null,
            child: path == null || (!path.startsWith('http') && !File(path).existsSync())
                ? Icon(Icons.person, size: 40, color: theme.textColor.withValues(alpha: 0.3))
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: theme.accentColor, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(TextEditingController controller, String label, dynamic theme) {
    return GlassContainer(
      opacity: 0.05,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        style: TextStyle(color: theme.textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme.textColor.withValues(alpha: 0.3), fontSize: 12),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, RelationshipProvider rp) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentLoveTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 12),
            Text(
              'Log Out',
              style: AppTypography.cardTitle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'This will erase all your local data including memories, settings, and theme preferences.\n\nAre you sure?',
          style: AppTypography.body(
            color: theme.textColor.withValues(alpha: 0.7),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Keep Logged In',
              style: AppTypography.body(
                color: theme.textColor.withValues(alpha: 0.54),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // close dialog
              await rp.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Log Out',
              style: AppTypography.body(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final rp = context.watch<RelationshipProvider>();

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: AppTypography.pageTitle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
             const SizedBox(height: 32),
            _buildLiquidProfileCard(rp, theme, context),
            const SizedBox(height: 40),
            _buildSectionHeader('Experience', theme),
            _buildModernTile(
              icon: Icons.palette_outlined,
              title: 'App Theme',
              subtitle: theme.name,
              theme: theme,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ThemeSelectorScreen()),
                );
              },
            ),
             const SizedBox(height: 32),
            _buildSectionHeader('Connection', theme),
            _buildModernTile(
              icon: Icons.favorite_outline_rounded,
              title: 'Relationship Profile',
              subtitle: rp.partnerId != null ? 'Connected with partner' : 'Waiting for connection',
              theme: theme,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RelationshipProfileScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildPremiumGlassCard(rp, theme),
            const SizedBox(height: 12),
            _buildModernTile(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              subtitle: 'Sign out of this session',
              theme: theme,
              onTap: () => _showLogoutConfirmation(context, rp),
            ),
             const SizedBox(height: 48),
            Center(
              child: Opacity(
                opacity: 0.2,
                child: Text(
                  'Version 0.1.0 • Built with ❤️',
                  style: AppTypography.caption(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }

  Widget _buildLiquidProfileCard(RelationshipProvider provider, dynamic theme, BuildContext context) {
    final partnerJoined = provider.partnerId != null;

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 30,
      opacity: 0.1,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniAvatar(provider.yourAvatarPath, provider.yourName ?? 'You', theme),
              Icon(Icons.favorite_rounded, color: theme.accentColor, size: 28),
              _buildMiniAvatar(
                partnerJoined ? provider.partnerAvatarPath : null,
                partnerJoined ? (provider.partnerName ?? 'Partner') : 'Waiting...',
                theme,
              ),
            ],
          ),
           const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _editProfileDialog(context, provider, theme),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Edit Profiles',
                style: AppTypography.caption(
                  color: theme.textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAvatar(String? path, String name, dynamic theme) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white10,
              backgroundImage: path != null
                  ? (path.startsWith('http')
                      ? NetworkImage(path) as ImageProvider
                      : (File(path).existsSync()
                          ? FileImage(File(path))
                          : null))
                  : null,
              child: path == null || (!path.startsWith('http') && !File(path).existsSync())
                  ? Icon(Icons.person, color: theme.textColor.withValues(alpha: 0.24))
                  : null,
            ),
          ),
           const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              color: theme.textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

   Widget _buildSectionHeader(String title, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption(
          color: theme.textColor.withValues(alpha: 0.3),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ).copyWith(letterSpacing: 2),
      ),
    );
  }

  Widget _buildModernTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required dynamic theme,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      borderRadius: 20,
      opacity: 0.03,
      child: ListTile(
        onTap: onTap,
         contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: theme.textColor.withValues(alpha: 0.7), size: 20),
        ),
        title: Text(title, style: AppTypography.body(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: AppTypography.caption(color: theme.textColor.withValues(alpha: 0.4), fontSize: 12)),
        trailing: Icon(Icons.chevron_right_rounded, color: theme.textColor.withValues(alpha: 0.24), size: 20),
      ),
    );
  }

  Widget _buildPremiumGlassCard(RelationshipProvider provider, dynamic theme) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(4),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.amber.withValues(alpha: 0.15),
          Colors.amber.withValues(alpha: 0.05),
        ],
      ),
      child: ListTile(
         leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
          child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
        ),
        title: Text('Premium Studio', style: AppTypography.body(color: theme.textColor, fontWeight: FontWeight.bold)),
        subtitle: Text('Unlock exclusive liquid glass themes', style: AppTypography.caption(color: theme.textColor.withValues(alpha: 0.54), fontSize: 11)),
        trailing: Switch.adaptive(
          value: provider.isPremium,
          onChanged: (val) => provider.setPremium(val),
          activeTrackColor: Colors.amber,
        ),
      ),
    );
  }
}
