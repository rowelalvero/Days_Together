import 'package:days_together/themes/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ConsumerWidget, WidgetRef;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/noteit_provider.dart';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/providers/daily_mood_provider.dart';
import 'package:days_together/providers/calendar_provider.dart';
import 'package:days_together/providers/time_capsule_provider.dart';
import 'package:days_together/providers/vault_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/shared/cached_avatar.dart';
import 'package:days_together/screens/wrapped/wrapped_service.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  Future<void> _launchWrapped(BuildContext context, WidgetRef ref) async {
    final year = DateTime.now().year;
    final workspace = ref.read(workspaceControllerProvider);
    final profile = ref.read(profileControllerProvider);
    final tp = context.read<TimelineProvider>();
    final np = context.read<NoteitProvider>();
    final bp = context.read<BucketListProvider>();
    final mp = context.read<DailyMoodProvider>();
    final cp = context.read<CalendarProvider>();
    final cap = context.read<TimeCapsuleProvider>();
    final vp = context.read<VaultProvider>();

    final data = WrappedService.aggregate(
      year: year,
      workspace: workspace,
      profile: profile,
      tp: tp,
      np: np,
      bp: bp,
      mp: mp,
      cp: cp,
      cap: cap,
      vp: vp,
    );

    if (!context.mounted) return;
    context.push(Routes.wrapped, extra: data);
  }

  void _showLogoutConfirmation(BuildContext context, CoupleSession session) {
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
              style: AppTypography.title(
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
              // No explicit navigation after this: logging out clears
              // CoupleSession's identity fields, which the router's single
              // redirect (app_router.dart) picks up via refreshListenable
              // and recomputes the correct destination for -- replacing the
              // old pushAndRemoveUntil(AppHome())/popUntil two-strategies
              // split ADR-007 found (this screen previously also imported
              // main.dart just to reach AppHome, a layering violation).
              await session.logout();
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
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final session = context.watch<CoupleSession>();
    final profile = ref.watch(profileControllerProvider);
    final workspace = ref.watch(workspaceControllerProvider);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: AppTypography.display(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 32),
            _buildLiquidProfileCard(session, profile, theme, context),
            const SizedBox(height: 40),
            _buildSectionHeader('Experience', theme),
            _buildModernTile(
              icon: Icons.palette_outlined,
              title: 'App Theme',
              subtitle: theme.name,
              theme: theme,
              onTap: () => context.push(Routes.themeSelector),
            ),
            const SizedBox(height: 12),
            _buildModernTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'Configure alerts & quiet hours',
              theme: theme,
              onTap: () => context.push(Routes.notificationSettings),
            ),
            const SizedBox(height: 12),
            _buildWrappedTile(theme, context, ref),
            const SizedBox(height: 8),
            _buildWrappedArchiveTile(theme, context),
            const SizedBox(height: 32),
            _buildSectionHeader('Connection', theme),
            _buildModernTile(
              icon: Icons.favorite_outline_rounded,
              title: 'Relationship Profile',
              subtitle: session.partnerId != null
                  ? 'Connected with partner'
                  : 'Waiting for connection',
              theme: theme,
              onTap: () => context.push(Routes.profile),
            ),
            const SizedBox(height: 12),
            _buildPremiumGlassCard(workspace, ref, theme),
            const SizedBox(height: 12),
            _buildModernTile(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              subtitle: 'Sign out of this session',
              theme: theme,
              onTap: () => _showLogoutConfirmation(context, session),
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

  Widget _buildWrappedTile(LoveStoryTheme theme, BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _launchWrapped(context, ref),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6B21A8), Color(0xFFBE185D), Color(0xFF1D4ED8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B21A8).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('❤️', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Days Together Wrapped',
                    style: AppTypography.body(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your ${DateTime.now().year} year in review',
                    style: AppTypography.body(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildWrappedArchiveTile(LoveStoryTheme theme, BuildContext context) {
    return _buildModernTile(
      icon: Icons.history_rounded,
      title: 'Wrapped Archive',
      subtitle: 'Revisit past years',
      theme: theme,
      onTap: () => context.push(Routes.wrappedArchive),
    );
  }

  Widget _buildLiquidProfileCard(
    CoupleSession session,
    ProfileState profile,
    LoveStoryTheme theme,
    BuildContext context,
  ) {
    final partnerJoined = session.partnerId != null;

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
                profile.yourAvatarPath,
                profile.yourName ?? 'You',
                theme,
              ),
              Icon(Icons.favorite_rounded, color: theme.accentColor, size: 28),
              _buildMiniAvatar(
                partnerJoined ? profile.partnerAvatarPath : null,
                partnerJoined
                    ? (profile.partnerName ?? 'Partner')
                    : 'Waiting...',
                theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAvatar(String? path, String name, LoveStoryTheme theme) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CachedAvatar(
              path: path,
              radius: 30,
              backgroundColor: theme.textColor.withValues(alpha: 0.1),
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

  Widget _buildSectionHeader(String title, LoveStoryTheme theme) {
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
    required LoveStoryTheme theme,
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

  Widget _buildPremiumGlassCard(WorkspaceState workspace, WidgetRef ref, LoveStoryTheme theme) {
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
          value: workspace.isPremium,
          onChanged: (val) => ref.read(workspaceControllerProvider.notifier).setPremium(val),
          activeTrackColor: Colors.amber,
        ),
      ),
    );
  }
}
