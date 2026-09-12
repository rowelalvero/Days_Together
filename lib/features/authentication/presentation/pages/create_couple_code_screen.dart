import 'dart:async';
import 'package:days_together/features/authentication/presentation/pages/genesis_screen.dart';
import 'package:days_together/features/authentication/presentation/widgets/code_actions_row.dart';
import 'package:days_together/features/authentication/presentation/widgets/connection_code_card.dart';
import 'package:days_together/features/authentication/presentation/widgets/continue_button.dart';
import 'package:days_together/features/authentication/presentation/widgets/generate_new_code_button.dart';
import 'package:days_together/features/authentication/presentation/widgets/recovery_code_card.dart';
import 'package:days_together/features/authentication/presentation/widgets/recovery_saved_checkbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/shared/widgets/safe_loading_dialog.dart';
import 'package:share_plus/share_plus.dart';

/// The "here's your connection code" screen shown to a couple's creator
/// before their partner joins.
///
/// Its inline connection-code/recovery-code cards and `_buildButton`
/// helper were extracted into widgets under `presentation/widgets/`
/// (Migration audit item 6) -- this class still owns the pairing-code
/// state (the generated code, animation controller, rotation timer) and
/// the copy/saved flags, matching how this app's other extracted forms
/// keep state on their own State.
class CreateCoupleCodeScreen extends ConsumerStatefulWidget {
  const CreateCoupleCodeScreen({super.key});

  @override
  ConsumerState<CreateCoupleCodeScreen> createState() =>
      _CreateCoupleCodeScreenState();
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
    _code =
        ref.read(workspaceControllerProvider).coupleCode ??
        workspace.generateCoupleCode();
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

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _copyRecoveryCode(String? recoveryCode) {
    Clipboard.setData(ClipboardData(text: recoveryCode ?? ''));
    setState(() => _copiedRecovery = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedRecovery = false);
    });
  }

  Future<void> _generateNewCode() async {
    final messenger = ScaffoldMessenger.of(context);
    final newCode = await ref
        .read(workspaceControllerProvider.notifier)
        .refreshPairingCode(forceRotate: true);
    if (mounted && newCode != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✨ Generated a fresh connection code!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _continue() {
    // Wipe recovery code from memory for security
    ref.read(workspaceControllerProvider.notifier).clearRecoveryCode();
    // Deliberately NOT context.push(Routes.genesis): this button has no
    // isPaired gate, so a creator can reach it before their partner joins.
    // computeSessionStage's needsGenesis requires isPaired (matching this
    // app's pre-migration AppHome logic verbatim), so a router-mediated
    // push here would be immediately redirected back to /workspace by
    // app_router.dart's appRedirect -- a real behavior change from today's
    // app, where a pushed screen isn't re-validated against AppHome. Left
    // as a plain Navigator.push to preserve the existing "continue
    // regardless of pairing" flow; revisit once/if the product decides
    // whether that flow is actually correct.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GenesisScreen()),
    );
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            // A plain Column (with a trailing Spacer) overflowed on shorter
            // screens -- this screen has a lot of stacked content (code
            // display, copy/share row, generate-new-code button, recovery
            // code panel, checkbox, continue button) and nothing here
            // scales down, so on a Redmi 8 the bottom of that content --
            // including the "Generate New Code" button -- was getting
            // clipped off-screen instead of just being scrollable.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                IconButton(
                  onPressed: () async {
                    final session = ref.read(
                      sessionControllerProvider.notifier,
                    );
                    await SafeLoadingDialog.run(
                      context: context,
                      future: () => session.unlinkPartner(),
                      loadingMessage: 'Canceling workspace...',
                    );
                  },
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: theme.textColor,
                  ),
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
                ConnectionCodeCard(
                  animController: _animController,
                  codeToDisplay: codeToDisplay,
                  theme: theme,
                ),
                const SizedBox(height: 20),
                CodeActionsRow(
                  copied: _copied,
                  hasCode: codeToDisplay.isNotEmpty,
                  onCopy: () => _copyCode(codeToDisplay),
                  onShare: () => Share.share(
                    'Connect with me on Days Together! Enter my connection code: $codeToDisplay to link our hearts 💕',
                  ),
                  theme: theme,
                ),
                const SizedBox(height: 12),
                GenerateNewCodeButton(
                  theme: theme,
                  onPressed: _generateNewCode,
                ),
                const SizedBox(height: 16),
                RecoveryCodeCard(
                  recoveryCode: workspace.recoveryCode,
                  copied: _copiedRecovery,
                  onCopy: () => _copyRecoveryCode(workspace.recoveryCode),
                  theme: theme,
                ),
                const SizedBox(height: 24),
                RecoverySavedCheckbox(
                  value: _savedRecoveryCode,
                  onChanged: (val) =>
                      setState(() => _savedRecoveryCode = val ?? false),
                  theme: theme,
                ),
                const SizedBox(height: 16),
                ContinueButton(
                  onPressed: _savedRecoveryCode ? _continue : null,
                  theme: theme,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
