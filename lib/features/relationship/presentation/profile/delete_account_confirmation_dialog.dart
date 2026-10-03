import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget;

import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/shared/widgets/glass_container.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// Confirms permanent account deletion before calling
/// `CoupleSession.deleteAccount()`. Extracted out of
/// `RelationshipProfileScreen._showDeleteAccountConfirmation` (per
/// `god-file-decomposition.md` item 5).
class DeleteAccountConfirmationDialog extends ConsumerStatefulWidget {
  const DeleteAccountConfirmationDialog({super.key, required this.theme});

  final LoveStoryTheme theme;

  static void show(BuildContext context, LoveStoryTheme theme) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => DeleteAccountConfirmationDialog(theme: theme),
    );
  }

  @override
  ConsumerState<DeleteAccountConfirmationDialog> createState() =>
      _DeleteAccountConfirmationDialogState();
}

class _DeleteAccountConfirmationDialogState
    extends ConsumerState<DeleteAccountConfirmationDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _deleteAccount() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).deleteAccount();
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error =
            'Could not delete your account. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return PopScope(
      canPop: !_deleting,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: 28,
          padding: const EdgeInsets.all(28),
          opacity: theme.isDark ? 0.1 : 0.85,
          gradient: theme.isDark
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.85),
                  ],
                ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.redAccent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Delete Account',
                style: AppTypography.heading(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Are you absolutely sure you want to delete your account? This action is permanent. All your personal data will be erased immediately. If you are paired, your partner will be returned to a single state and all shared memories and notes will be deleted forever.',
                style: AppTypography.body(
                  fontSize: 14,
                  color: theme.textColor.withValues(alpha: 0.6),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTypography.body(
                    color: Colors.redAccent,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 28),
              if (_deleting)
                const CircularProgressIndicator(color: Colors.redAccent)
              else
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: AppTypography.body(
                            color: theme.textColor.withValues(alpha: 0.4),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _deleteAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Delete',
                          style: AppTypography.body(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
