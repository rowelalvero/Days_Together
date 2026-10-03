import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/app/router/route_names.dart';

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

  final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );
  String? _errorMessage;
  bool _isValidating = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _fullCode => _controllers.map((c) => c.text).join().toUpperCase();

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
                  // One box per character. Expanded (not a fixed width) so
                  // eight boxes still fit a narrow phone.
                  Row(
                    children: List.generate(_codeLength, (index) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: SizedBox(
                            height: 60,
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              textCapitalization: TextCapitalization.characters,
                              style: AppTypography.body(
                                color: theme.textColor,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: theme.textColor.withValues(
                                  alpha: 0.05,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _errorMessage != null
                                        ? theme.accentColor
                                        : theme.textColor.withValues(
                                            alpha: 0.15,
                                          ),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _errorMessage != null
                                        ? theme.accentColor
                                        : theme.textColor.withValues(
                                            alpha: 0.15,
                                          ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: theme.accentColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() => _errorMessage = null);
                                if (value.isNotEmpty &&
                                    index < _codeLength - 1) {
                                  _focusNodes[index + 1].requestFocus();
                                }
                                if (_fullCode.length == _codeLength &&
                                    !_isValidating) {
                                  _validateCode();
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _errorMessage!,
                      style: AppTypography.body(
                        color: theme.accentColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed:
                          _fullCode.length == _codeLength && !_isValidating
                          ? _validateCode
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: theme.accentColor.withValues(
                          alpha: 0.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isValidating
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
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
      final success = await session.joinWithCode(_fullCode);
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
