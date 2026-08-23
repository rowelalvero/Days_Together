import 'package:days_together/themes/theme_manager.dart';
import 'dart:async';
import 'package:days_together/screens/onboarding/genesis_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/shared/safe_loading_dialog.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class CreateCoupleCodeScreen extends ConsumerStatefulWidget {
  const CreateCoupleCodeScreen({super.key});

  @override
  ConsumerState<CreateCoupleCodeScreen> createState() => _CreateCoupleCodeScreenState();
}

class _CreateCoupleCodeScreenState extends ConsumerState<CreateCoupleCodeScreen>
    with SingleTickerProviderStateMixin {
  late String _code;
  late AnimationController _animController;
  Timer? _rotationTimer;
  bool _copied = false;
  bool _copiedRecovery = false;
  bool _savedRecoveryCode = false;

  @override
  void initState() {
    super.initState();
    final workspace = ref.read(workspaceControllerProvider.notifier);
    _code = ref.read(workspaceControllerProvider).coupleCode ?? workspace.generateCoupleCode();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    // Check/refresh active pairing code on open & schedule periodic checks
    workspace.refreshPairingCode();
    _rotationTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) {
        ref.read(workspaceControllerProvider.notifier).refreshPairingCode();
      }
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final workspace = ref.watch(workspaceControllerProvider);
    final codeToDisplay = workspace.coupleCode ?? _code;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                IconButton(
                  onPressed: () async {
                    final session = context.read<CoupleSession>();
                    await SafeLoadingDialog.run(
                      context: context,
                      future: () => session.unlinkPartner(),
                      loadingMessage: 'Canceling workspace...',
                    );
                  },
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
                ),
                const SizedBox(height: 20),
                Text(
                  'Your unique\nconnection code.',
                  style: AppTypography.cormorant(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share this with your partner to invite them into your story.',
                  style: AppTypography.spectral(
                    fontSize: 14,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),
                // Code Display
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _animController,
                    curve: Curves.elasticOut,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: theme.textColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.accentColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accentColor.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (codeToDisplay.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: CircularProgressIndicator(),
                          )
                        else
                          Text(
                            codeToDisplay,
                            style: AppTypography.body(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: theme.textColor,
                            ).copyWith(letterSpacing: 10),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          '⏱️ Code changes every 20 mins while waiting to connect.',
                          style: AppTypography.caption(
                            fontSize: 12,
                            color: theme.textColor.withValues(alpha: 0.6),
                          ).copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildButton(
                        label: _copied ? '✓ Copied' : 'Copy Code',
                        icon: Icons.copy_rounded,
                        onPressed: codeToDisplay.isEmpty
                            ? () {}
                            : () {
                                Clipboard.setData(ClipboardData(text: codeToDisplay));
                                setState(() => _copied = true);
                                Future.delayed(const Duration(seconds: 2), () {
                                  if (mounted) setState(() => _copied = false);
                                });
                              },
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildButton(
                        label: 'Share',
                        icon: Icons.share_rounded,
                        onPressed: codeToDisplay.isEmpty
                            ? () {}
                            : () {
                                Share.share(
                                  'Connect with me on Days Together! Enter my connection code: $codeToDisplay to link our hearts 💕',
                                );
                              },
                        theme: theme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Recovery Code Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Recovery Code',
                        style: AppTypography.body(
                          color: theme.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        workspace.recoveryCode ?? '—',
                        style: AppTypography.body(
                          color: theme.accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '⚠️ This code will never be shown again. Use it to recover your workspace if you disconnect.',
                        style: AppTypography.caption(
                          color: theme.textColor.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: workspace.recoveryCode ?? ''));
                            setState(() => _copiedRecovery = true);
                            Future.delayed(const Duration(seconds: 2), () {
                              if (mounted) setState(() => _copiedRecovery = false);
                            });
                          },
                          icon: Icon(_copiedRecovery ? Icons.check_circle_outline : Icons.copy_all_rounded, size: 16),
                          label: Text(_copiedRecovery ? 'Copied!' : 'Copy Recovery Code'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.textColor,
                            side: BorderSide(color: theme.textColor.withValues(alpha: 0.15)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Checkbox(
                      value: _savedRecoveryCode,
                      onChanged: (val) => setState(() => _savedRecoveryCode = val ?? false),
                      activeColor: theme.accentColor,
                    ),
                    Expanded(
                      child: Text(
                        'I have copied and saved my recovery code.',
                        style: AppTypography.body(
                          color: theme.textColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _savedRecoveryCode
                        ? () {
                            // Wipe recovery code from memory for security
                            ref.read(workspaceControllerProvider.notifier).clearRecoveryCode();
                            // Deliberately NOT context.push(Routes.genesis):
                            // this button has no isPaired gate, so a creator
                            // can reach it before their partner joins.
                            // computeSessionStage's needsGenesis requires
                            // isPaired (matching this app's pre-migration
                            // AppHome logic verbatim), so a router-mediated
                            // push here would be immediately redirected back
                            // to /workspace by app_router.dart's appRedirect
                            // -- a real behavior change from today's app,
                            // where a pushed screen isn't re-validated
                            // against AppHome. Left as a plain Navigator.push
                            // to preserve the existing "continue regardless
                            // of pairing" flow; revisit once/if the product
                            // decides whether that flow is actually correct.
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GenesisScreen(),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: theme.accentColor.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Continue',
                      style: AppTypography.button(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required LoveStoryTheme theme,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.textColor,
        side: BorderSide(color: theme.textColor.withValues(alpha: 0.15)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
