import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/app/router/route_names.dart';
import 'package:days_together/shared/widgets/otp_input.dart';

class JoinCoupleCodeScreen extends ConsumerStatefulWidget {
  const JoinCoupleCodeScreen({super.key});

  @override
  ConsumerState<JoinCoupleCodeScreen> createState() =>
      _JoinCoupleCodeScreenState();
}

class _JoinCoupleCodeScreenState extends ConsumerState<JoinCoupleCodeScreen> {
  /// Server-issued pairing codes are 8 characters
  /// (20261003000200_harden_pairing.sql).
  static const int _codeLength = 8;

  String _code = '';
  String? _errorMessage;
  bool _isValidating = false;

  bool get _isComplete => _code.length == _codeLength;

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Enter the\nmagic code.',
                    style: AppTypography.cormorant(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter the $_codeLength-character connection code sent by your partner.',
                    style: AppTypography.spectral(
                      fontSize: 16,
                      color: theme.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 60),
                  OtpInput(
                    theme: theme,
                    length: _codeLength,
                    charset: OtpCharset.alphanumeric,
                    groupSize: 4,
                    hint: 'Letters and numbers, any case.',
                    autofocus: true,
                    semanticLabel: 'Connection code',
                    status: _errorMessage != null
                        ? OtpStatus.error
                        : OtpStatus.idle,
                    errorMessage: _errorMessage,
                    onChanged: (code) {
                      setState(() {
                        _code = code;
                        _errorMessage = null;
                      });
                      // Re-checks on every full code, so fixing one
                      // character after a miss submits again.
                      if (_isComplete) _validateCode();
                    },
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isComplete && !_isValidating
                          ? _validateCode
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: theme.onAccentColor,
                        // Disabled reads as "not yet" but its label stays
                        // legible: text ink on a faint accent wash.
                        disabledBackgroundColor: theme.accentColor.withValues(
                          alpha: 0.18,
                        ),
                        disabledForegroundColor: theme.textColor.withValues(
                          alpha: 0.55,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isValidating
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: theme.textColor,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Link Connection Code',
                              style: AppTypography.button(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _validateCode() async {
    if (_isValidating) return;
    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });
    try {
      final session = ref.read(sessionControllerProvider.notifier);
      final success = await session.joinWithCode(_code);
      if (!mounted) return;
      if (success) {
        context.push(Routes.avatar);
      } else {
        setState(() {
          _errorMessage =
              'Hmm, we couldn\'t find that connection code. Please check it with your partner.';
          _isValidating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // CoupleSession.joinWithCode throws an already user-facing message
          // mapped from the RPC's error_code (pairingFailureMessage).
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isValidating = false;
        });
      }
    }
  }
}
