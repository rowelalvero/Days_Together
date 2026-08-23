import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/shared/safe_loading_dialog.dart';

class PairingSelectionScreen extends ConsumerStatefulWidget {
  const PairingSelectionScreen({super.key});

  @override
  ConsumerState<PairingSelectionScreen> createState() => _PairingSelectionScreenState();
}

class _PairingSelectionScreenState extends ConsumerState<PairingSelectionScreen> {
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            // A plain Column with Spacers overflowed on shorter screens (the
            // fixed-height back button + heading + 3 cards don't always fit
            // even with both Spacers shrunk to zero -- e.g. a Redmi 8).
            // Spacer requires bounded height from its Flex parent, which a
            // scrollable's unbounded height can't provide, so the two
            // Spacers below are replaced with fixed gaps.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                IconButton(
                  // This screen is only ever reached via appRedirect's
                  // stage-based redirect (SessionStage.needsCouple), never
                  // pushed from another screen -- there is nothing beneath
                  // it in the Navigator stack for Navigator.pop(context) to
                  // return to, which left the screen rendering blank. The
                  // sensible "back" action here is logging out: nothing
                  // relationship-scoped has been created yet at this stage,
                  // so it cleanly returns to the true starting point instead
                  // of popping into an empty stack.
                  onPressed: () {
                    ref.read(sessionControllerProvider.notifier).logout();
                  },
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'How would you like to\nbegin your story?',
                  style: AppTypography.cormorant(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose a path to connect.',
                  style: AppTypography.spectral(
                    fontSize: 16,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 40),
                _PairingCard(
                  icon: Icons.favorite_rounded,
                  title: "Create Relationship",
                  subtitle: "Start a new shared relationship workspace.",
                  accentColor: theme.accentColor,
                  textColor: theme.textColor,
                  onTap: () async {
                    if (_isNavigating) return;
                    _isNavigating = true;
                    final workspaceNotifier = ref.read(workspaceControllerProvider.notifier);
                    await SafeLoadingDialog.run<bool>(
                      context: context,
                      future: () async {
                        await workspaceNotifier.createRelationshipWorkspace();
                        return true;
                      },
                      timeoutSeconds: 15,
                      loadingMessage: 'Creating workspace...',
                    );
                    if (mounted) _isNavigating = false;
                  },
                ),
                const SizedBox(height: 16),
                _PairingCard(
                  icon: Icons.link_rounded,
                  title: "Join with Pairing Code",
                  subtitle:
                      "Connect to your partner's newly created workspace.",
                  accentColor: theme.accentColor,
                  textColor: theme.textColor,
                  onTap: () {
                    if (_isNavigating) return;
                    _isNavigating = true;
                    context.push(Routes.joinCode).then((_) {
                      if (mounted) _isNavigating = false;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _PairingCard(
                  icon: Icons.security_rounded,
                  title: "Recover Existing Relationship",
                  subtitle:
                      "Reconnect to a workspace you previously belonged to.",
                  accentColor: theme.accentColor,
                  textColor: theme.textColor,
                  onTap: () {
                    if (_isNavigating) return;
                    _isNavigating = true;
                    context.push(Routes.recover).then((_) {
                      if (mounted) _isNavigating = false;
                    });
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PairingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  const _PairingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: textColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.caption(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
