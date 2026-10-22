import 'dart:async';
import 'package:days_together/features/authentication/presentation/pages/genesis_screen.dart';
import 'package:days_together/features/authentication/presentation/widgets/auth_page_frame.dart';
import 'package:days_together/features/authentication/presentation/widgets/connection_code_card.dart';
import 'package:days_together/features/authentication/presentation/widgets/continue_button.dart';
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
    );
    // Respect reduce-motion: start settled instead of animating in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _animController.value = 1;
      } else {
        _animController.forward();
      }
    });

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
          content: Text(
            'New connection code ready. The old one no longer works.',
          ),
          duration: Duration(seconds: 3),
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

  /// Leaving this screen cancels the brand-new workspace, so ask first --
  /// the codes on screen stop working the moment it's gone.
  Future<void> _confirmLeave() async {
    final theme = ref.read(themeControllerProvider).currentLoveTheme;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave without connecting?'),
        content: const Text(
          'This cancels your new workspace. Your connection code and '
          'recovery code will stop working.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: theme.semantic.error),
            child: const Text('Cancel workspace'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    final session = ref.read(sessionControllerProvider.notifier);
    await SafeLoadingDialog.run(
      context: context,
      future: () => session.unlinkPartner(),
      loadingMessage: 'Canceling workspace...',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final workspace = ref.watch(workspaceControllerProvider);
    final codeToDisplay = workspace.coupleCode ?? _code;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: AuthPageFrame(
        theme: theme,
        gradient: themeProvider.currentGradient,
        onBack: _confirmLeave,
        title: 'Invite your partner',
        subtitle:
            'Share your connection code so they can join your story, then '
            'save your recovery code.',
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Says why Continue is disabled instead of leaving a dead button.
            if (!_savedRecoveryCode)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Save your recovery code to continue.',
                  style: AppTypography.body(
                    fontSize: 13,
                    color: theme.textColor.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ContinueButton(
              onPressed: _savedRecoveryCode ? _continue : null,
              theme: theme,
            ),
          ],
        ),
        children: [
          AuthStepHeader(number: 1, title: 'Share your code', theme: theme),
          const SizedBox(height: 12),
          ConnectionCodeCard(
            animController: _animController,
            codeToDisplay: codeToDisplay,
            copied: _copied,
            onCopy: () => _copyCode(codeToDisplay),
            onShare: () => Share.share(
              'Connect with me on Days Together! Enter my connection code: '
              '$codeToDisplay to link our hearts 💕',
            ),
            onNewCode: _generateNewCode,
            theme: theme,
          ),
          const SizedBox(height: 28),
          AuthStepHeader(
            number: 2,
            title: 'Save your recovery code',
            theme: theme,
          ),
          const SizedBox(height: 12),
          RecoveryCodeCard(
            recoveryCode: workspace.recoveryCode,
            copied: _copiedRecovery,
            onCopy: () => _copyRecoveryCode(workspace.recoveryCode),
            theme: theme,
            footer: RecoverySavedCheckbox(
              value: _savedRecoveryCode,
              onChanged: (val) =>
                  setState(() => _savedRecoveryCode = val ?? false),
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }
}
