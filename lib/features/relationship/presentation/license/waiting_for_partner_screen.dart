import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Shown while waiting for the partner to join or complete their own
/// license setup. Extracted out of
/// `RelationshipLicenseScreenState._buildWaitingForPartnerScreen`
/// (Migration Phase 8).
class WaitingForPartnerScreen extends ConsumerWidget {
  const WaitingForPartnerScreen({
    super.key,
    required this.theme,
    required this.partnerJoined,
  });

  final LoveStoryTheme theme;
  final bool partnerJoined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Relationship License',
          style: AppTypography.heading(fontWeight: FontWeight.bold, color: theme.textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: ref.watch(themeControllerProvider).currentGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: GlassContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(32),
                opacity: 0.1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_empty_rounded,
                        size: 48,
                        color: theme.accentColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      partnerJoined ? 'Waiting for Partner' : 'Waiting for Partner to Join',
                      style: AppTypography.heading(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      partnerJoined
                          ? "We are waiting for your partner to complete their license setup before details can be shared and viewed."
                          : "Please connect with your partner first. Once they join and complete their setup, your licenses will be synced and visible here.",
                      style: AppTypography.body(fontSize: 14, color: theme.textColor.withValues(alpha: 0.7), height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.textColor.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
