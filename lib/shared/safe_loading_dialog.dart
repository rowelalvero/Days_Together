import 'dart:async';
import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';

/// A production-safe loading dialog that wraps any async [Future] with:
///
/// - A configurable **timeout** (default 15s) that auto-dismisses on expiry
/// - A **cancel button** that appears after [cancelDelaySeconds] (default 5s)
/// - Theme-aware styling consistent with the app's glass aesthetic
///
/// Usage:
/// ```dart
/// final result = await SafeLoadingDialog.run<bool>(
///   context: context,
///   future: () => provider.createRelationshipWorkspace(),
///   timeoutSeconds: 15,
///   loadingMessage: 'Creating workspace...',
/// );
/// ```
class SafeLoadingDialog {
  /// Runs [future] inside a non-dismissible loading dialog.
  ///
  /// Returns the result of [future] on success, or `null` on timeout/cancel/error.
  /// The dialog is always dismissed before this method returns.
  static Future<T?> run<T>({
    required BuildContext context,
    required Future<T> Function() future,
    int timeoutSeconds = 15,
    int cancelDelaySeconds = 5,
    String loadingMessage = 'Please wait...',
    String? timeoutMessage,
    Color? indicatorColor,
  }) async {
    // Ensure we have a valid context
    if (!context.mounted) return null;

    T? result;
    bool dismissed = false;
    bool timedOut = false;

    // Create a completer to track when the dialog is actually popped
    final dialogCompleter = Completer<void>();

    void safeDismiss(BuildContext dialogContext) {
      if (!dismissed && dialogContext.mounted) {
        dismissed = true;
        Navigator.of(dialogContext).pop();
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _SafeLoadingDialogContent(
          future: () async {
            try {
              result = await future().timeout(
                Duration(seconds: timeoutSeconds),
                onTimeout: () {
                  timedOut = true;
                  throw TimeoutException(
                    timeoutMessage ?? 'Operation timed out. Please check your connection and try again.',
                    Duration(seconds: timeoutSeconds),
                  );
                },
              );
            } catch (e) {
              if (!timedOut) {
                rethrow;
              }
            } finally {
              // safeDismiss already checks dialogContext.mounted
              safeDismiss(dialogContext); // ignore: use_build_context_synchronously
            }
          },
          loadingMessage: loadingMessage,
          cancelDelaySeconds: cancelDelaySeconds,
          indicatorColor: indicatorColor,
          onCancel: () => safeDismiss(dialogContext),
        );
      },
    ).then((_) {
      if (!dialogCompleter.isCompleted) {
        dialogCompleter.complete();
      }
    });

    // Wait for dialog to actually close
    await dialogCompleter.future;

    // Show timeout feedback if applicable
    if (timedOut && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            timeoutMessage ?? 'Operation timed out. Please check your connection and try again.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }

    return result;
  }
}

class _SafeLoadingDialogContent extends StatefulWidget {
  final Future<void> Function() future;
  final String loadingMessage;
  final int cancelDelaySeconds;
  final Color? indicatorColor;
  final VoidCallback onCancel;

  const _SafeLoadingDialogContent({
    required this.future,
    required this.loadingMessage,
    required this.cancelDelaySeconds,
    this.indicatorColor,
    required this.onCancel,
  });

  @override
  State<_SafeLoadingDialogContent> createState() =>
      _SafeLoadingDialogContentState();
}

class _SafeLoadingDialogContentState extends State<_SafeLoadingDialogContent> {
  bool _showCancel = false;
  Timer? _cancelTimer;

  @override
  void initState() {
    super.initState();

    // Defer the async operation to after the current build frame completes.
    // This prevents "setState() called during build" when the future
    // synchronously calls notifyListeners() on a provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.future();
      }
    });

    // Show cancel button after delay
    _cancelTimer = Timer(Duration(seconds: widget.cancelDelaySeconds), () {
      if (mounted) {
        setState(() => _showCancel = true);
      }
    });
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final isDark = themeData.brightness == Brightness.dark;
    final effectiveIndicatorColor = widget.indicatorColor ?? themeData.colorScheme.primary;
    final textColor = themeData.colorScheme.onSurface;

    return PopScope(
      canPop: false,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey.shade900.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: effectiveIndicatorColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.loadingMessage,
                style: AppTypography.body(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: _showCancel
                    ? Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: TextButton(
                          onPressed: widget.onCancel,
                          style: TextButton.styleFrom(
                            foregroundColor: textColor.withValues(alpha: 0.4),
                          ),
                          child: Text(
                            'Cancel',
                            style: AppTypography.body(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
