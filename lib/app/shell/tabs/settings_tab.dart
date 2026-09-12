import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerWidget, WidgetRef;
import 'package:go_router/go_router.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/shell/dialogs/logout_confirmation_dialog.dart';
import 'package:days_together/app/shell/widgets/liquid_profile_card.dart';
import 'package:days_together/app/shell/widgets/premium_glass_card.dart';
import 'package:days_together/app/shell/widgets/settings_section_header.dart';
import 'package:days_together/app/shell/widgets/settings_tile.dart';
import 'package:days_together/app/shell/widgets/wrapped_tile.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/features/mood/daily_mood_controller.dart';
import 'package:days_together/features/calendar/calendar_controller.dart';
import 'package:days_together/features/love_studio/time_capsule_controller.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/app/router/route_names.dart';
import 'package:days_together/features/wrapped/data/wrapped_service.dart';

/// The "More" tab: profile summary, app settings, and account actions.
///
/// Its `_buildX` methods and inline logout confirmation dialog were
/// extracted into focused widgets under `app/shell/widgets/` and `app/
/// shell/dialogs/` (Migration audit item 6).
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  Future<void> _launchWrapped(BuildContext context, WidgetRef ref) async {
    final year = DateTime.now().year;
    final workspace = ref.read(workspaceControllerProvider);
    final profile = ref.read(profileControllerProvider);
    final tp = ref.read(timelineControllerProvider);
    final np = ref.read(noteitControllerProvider);
    final bp = ref.read(bucketListControllerProvider);
    final mp = ref.read(dailyMoodControllerProvider);
    final cp = ref.read(calendarControllerProvider);
    final cap = ref.read(timeCapsuleControllerProvider);

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
    );

    if (!context.mounted) return;
    context.push(Routes.wrapped, extra: data);
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeControllerProvider).currentLoveTheme;
    showDialog(
      context: context,
      builder: (ctx) => LogoutConfirmationDialog(
        theme: theme,
        onConfirm: () async {
          // No explicit navigation after this: logging out clears
          // CoupleSession's identity fields, which the router's single
          // redirect (app_router.dart) picks up via refreshListenable
          // and recomputes the correct destination for -- replacing the
          // old pushAndRemoveUntil(AppHome())/popUntil two-strategies
          // split ADR-007 found (this screen previously also imported
          // main.dart just to reach AppHome, a layering violation).
          await ref.read(sessionControllerProvider.notifier).logout();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider).currentLoveTheme;
    final session = ref.watch(sessionControllerProvider);
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
            LiquidProfileCard(session: session, profile: profile, theme: theme),
            const SizedBox(height: 40),
            SettingsSectionHeader(title: 'Experience', theme: theme),
            SettingsTile(
              icon: Icons.palette_outlined,
              title: 'App Theme',
              subtitle: theme.name,
              theme: theme,
              onTap: () => context.push(Routes.themeSelector),
            ),
            const SizedBox(height: 12),
            SettingsTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'Configure alerts & quiet hours',
              theme: theme,
              onTap: () => context.push(Routes.notificationSettings),
            ),
            const SizedBox(height: 12),
            WrappedTile(onTap: () => _launchWrapped(context, ref)),
            const SizedBox(height: 8),
            SettingsTile(
              icon: Icons.history_rounded,
              title: 'Wrapped Archive',
              subtitle: 'Revisit past years',
              theme: theme,
              onTap: () => context.push(Routes.wrappedArchive),
            ),
            const SizedBox(height: 32),
            SettingsSectionHeader(title: 'Connection', theme: theme),
            SettingsTile(
              icon: Icons.favorite_outline_rounded,
              title: 'Relationship Profile',
              subtitle: session.partnerId != null
                  ? 'Connected with partner'
                  : 'Waiting for connection',
              theme: theme,
              onTap: () => context.push(Routes.profile),
            ),
            const SizedBox(height: 12),
            PremiumGlassCard(
              isPremium: workspace.isPremium,
              theme: theme,
              onChanged: (val) => ref
                  .read(workspaceControllerProvider.notifier)
                  .setPremium(val),
            ),
            const SizedBox(height: 12),
            SettingsTile(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              subtitle: 'Sign out of this session',
              theme: theme,
              onTap: () => _showLogoutConfirmation(context, ref),
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
}
