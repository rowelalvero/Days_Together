import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/widgets/theme_selector.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/widgets/cached_avatar.dart';
import 'package:days_together/screens/settings/relationship_profile_screen.dart';
import 'package:days_together/screens/settings/notification_settings_screen.dart';
import 'package:days_together/main.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});



  void _showLogoutConfirmation(BuildContext context, RelationshipProvider rp) {
    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentLoveTheme;
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
                  MaterialPageRoute(builder: (_) => const AppHome()),
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
                  MaterialPageRoute(
                    builder: (_) => const ThemeSelectorScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildModernTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'Configure alerts & quiet hours',
              theme: theme,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('Connection', theme),
            _buildModernTile(
              icon: Icons.favorite_outline_rounded,
              title: 'Relationship Profile',
              subtitle: rp.partnerId != null
                  ? 'Connected with partner'
                  : 'Waiting for connection',
              theme: theme,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RelationshipProfileScreen(),
                  ),
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
                  style: AppTypography.caption(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }

  Widget _buildLiquidProfileCard(
    RelationshipProvider provider,
    dynamic theme,
    BuildContext context,
  ) {
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
              _buildMiniAvatar(
                provider.yourAvatarPath,
                provider.yourName ?? 'You',
                theme,
              ),
              Icon(Icons.favorite_rounded, color: theme.accentColor, size: 28),
              _buildMiniAvatar(
                partnerJoined ? provider.partnerAvatarPath : null,
                partnerJoined
                    ? (provider.partnerName ?? 'Partner')
                    : 'Waiting...',
                theme,
              ),
            ],
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
            child: CachedAvatar(
              path: path,
              radius: 30,
              placeholderColor: theme.textColor.withValues(alpha: 0.1),
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
          decoration: BoxDecoration(
            color: theme.textColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: theme.textColor.withValues(alpha: 0.7),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: AppTypography.body(
            color: theme.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.caption(
            color: theme.textColor.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: theme.textColor.withValues(alpha: 0.24),
          size: 20,
        ),
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
          decoration: const BoxDecoration(
            color: Colors.amber,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
        ),
        title: Text(
          'Premium Studio',
          style: AppTypography.body(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Unlock exclusive liquid glass themes',
          style: AppTypography.caption(
            color: theme.textColor.withValues(alpha: 0.54),
            fontSize: 11,
          ),
        ),
        trailing: Switch.adaptive(
          value: provider.isPremium,
          onChanged: (val) => provider.setPremium(val),
          activeTrackColor: Colors.amber,
        ),
      ),
    );
  }
}
