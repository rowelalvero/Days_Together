import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/relationship/presentation/profile/components/auth_debug_footer.dart';
import 'package:days_together/features/relationship/presentation/profile/components/danger_zone_section.dart';
import 'package:days_together/features/relationship/presentation/profile/components/pairing_options_section.dart';
import 'package:days_together/features/relationship/presentation/profile/components/partner_key_security_card.dart';
import 'package:days_together/features/relationship/presentation/profile/components/profile_app_bar.dart';
import 'package:days_together/features/relationship/presentation/profile/components/profile_header_section.dart';
import 'package:days_together/features/relationship/presentation/profile/components/profile_info_card.dart';
import 'package:days_together/features/relationship/presentation/profile/components/regenerate_recovery_code_button.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/theme/theme_controller.dart';

/// The signed-in user's relationship profile: both partners' avatars/names,
/// the anniversary date/time and duration, pairing options while waiting
/// for a partner, and the danger-zone account actions.
///
/// Its `_buildX` methods were extracted into focused widgets under
/// `components/` (Migration audit item 6) -- this class now only assembles
/// them from the three controllers it reads.
class RelationshipProfileScreen extends ConsumerWidget {
  const RelationshipProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final sessionState = ref.watch(sessionControllerProvider);
    final profileState = ref.watch(profileControllerProvider);
    final workspaceState = ref.watch(workspaceControllerProvider);
    final partnerJoined = sessionState.partnerId != null;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: Column(
            children: [
              ProfileAppBar(theme: theme),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProfileHeaderSection(
                        sessionState: sessionState,
                        profileState: profileState,
                        theme: theme,
                      ),
                      const SizedBox(height: 32),
                      ProfileInfoCard(
                        workspaceState: workspaceState,
                        profileState: profileState,
                        theme: theme,
                      ),
                      const SizedBox(height: 32),
                      if (partnerJoined) ...[
                        PartnerKeySecurityCard(theme: theme),
                        const SizedBox(height: 32),
                      ],
                      if (!partnerJoined &&
                          workspaceState.coupleCode != null) ...[
                        PairingOptionsSection(theme: theme),
                        const SizedBox(height: 32),
                      ],
                      const SizedBox(height: 16),
                      RegenerateRecoveryCodeButton(theme: theme),
                      const SizedBox(height: 16),
                      DangerZoneSection(
                        sessionState: sessionState,
                        theme: theme,
                      ),
                      const SizedBox(height: 24),
                      AuthDebugFooter(sessionState: sessionState, theme: theme),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
