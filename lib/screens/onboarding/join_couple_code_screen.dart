import 'package:days_together/screens/onboarding/genesis_screen.dart';
import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:provider/provider.dart';

class JoinCoupleCodeScreen extends StatefulWidget {
  const JoinCoupleCodeScreen({super.key});

  @override
  State<JoinCoupleCodeScreen> createState() => _JoinCoupleCodeScreenState();
}

class _JoinCoupleCodeScreenState extends State<JoinCoupleCodeScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
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

  String get _fullCode =>
      _controllers.map((c) => c.text).join().toUpperCase();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
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
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
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
                    'Your partner shared a 6-digit code with you.',
                    style: AppTypography.spectral(
                      fontSize: 16,
                      color: theme.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 60),
                  // 6-digit input
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 48,
                        height: 60,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          textCapitalization: TextCapitalization.characters,
                          style: AppTypography.body(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: _errorMessage != null
                                    ? theme.accentColor
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: _errorMessage != null
                                    ? theme.accentColor
                                    : Colors.white.withValues(alpha: 0.2),
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
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            }
                            if (_fullCode.length == 6) {
                              _validateCode();
                            }
                          },
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
                          _fullCode.length == 6 && !_isValidating
                              ? _validateCode
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            theme.accentColor.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 5,
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
                              'Link Couple Code',
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
    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });
    try {
      final provider = context.read<RelationshipProvider>();
      final success = await provider.joinWithCode(_fullCode);
      if (!mounted) return;
      if (success) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GenesisScreen()),
        );
      } else {
        setState(() {
          _errorMessage =
              '❌ Hmm, that code doesn\'t exist. Please double-check with your partner.';
          _isValidating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '❌ Error pairing: ${e.toString().replaceAll('Exception: ', '')}';
          _isValidating = false;
        });
      }
    }
  }
}
