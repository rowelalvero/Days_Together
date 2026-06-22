import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                        style: GoogleFonts.inter(
                          color: Colors.white54,
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
                        style: GoogleFonts.inter(
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
                ? const Icon(Icons.person, size: 40, color: Colors.white30)
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
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
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
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'This will erase all your local data including memories, settings, and theme preferences.\n\nAre you sure?',
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Keep Logged In',
              style: GoogleFonts.inter(
                color: Colors.white54,
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
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: GoogleFonts.playfairDisplay(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
             const SizedBox(height: 32),
            _buildLiquidProfileCard(rp, theme, context),
            const SizedBox(height: 40),
            _buildSectionHeader('Experience'),
            _buildModernTile(
              icon: Icons.palette_outlined,
              title: 'App Theme',
              subtitle: theme.name,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ThemeSelectorScreen()),
                );
              },
            ),
             const SizedBox(height: 32),
            _buildSectionHeader('Connection'),
            _buildModernTile(
              icon: Icons.favorite_outline_rounded,
              title: 'Relationship Profile',
              subtitle: rp.partnerId != null ? 'Connected with partner' : 'Waiting for connection',
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
              onTap: () => _showLogoutConfirmation(context, rp),
            ),
             const SizedBox(height: 48),
            Center(
              child: Opacity(
                opacity: 0.2,
                child: Text(
                  'Version 0.1.0 • Built with ❤️',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
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
              _buildMiniAvatar(provider.yourAvatarPath, provider.yourName ?? 'You'),
              Icon(Icons.favorite_rounded, color: theme.accentColor, size: 28),
              _buildMiniAvatar(
                partnerJoined ? provider.partnerAvatarPath : null,
                partnerJoined ? (provider.partnerName ?? 'Partner') : 'Waiting...',
              ),
            ],
          ),
           const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _editProfileDialog(context, provider, theme),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Edit Profiles',
                style: GoogleFonts.inter(
                  color: Colors.white,
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

  Widget _buildMiniAvatar(String? path, String name) {
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
                  ? const Icon(Icons.person, color: Colors.white24)
                  : null,
            ),
          ),
           const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

   Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildModernTile({
    required IconData icon,
    required String title,
    required String subtitle,
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
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
        title: Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
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
        title: Text('Premium Studio', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('Unlock exclusive liquid glass themes', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
        trailing: Switch.adaptive(
          value: provider.isPremium,
          onChanged: (val) => provider.setPremium(val),
          activeTrackColor: Colors.amber,
        ),
      ),
    );
  }
}
