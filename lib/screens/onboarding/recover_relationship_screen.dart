import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/screens/onboarding/avatar_creation_screen.dart';

class RecoverRelationshipScreen extends StatefulWidget {
  const RecoverRelationshipScreen({super.key});

  @override
  State<RecoverRelationshipScreen> createState() => _RecoverRelationshipScreenState();
}

class _RecoverRelationshipScreenState extends State<RecoverRelationshipScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleRecover() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final code = _codeController.text.trim();
    final provider = context.read<RelationshipProvider>();

    try {
      final success = await provider.recoverRelationship(code);
      if (success) {
        if (mounted) {
          // Show a beautiful loading dialog while we wait for the workspace data to sync
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );

          // Wait for the provider sync/initialization to complete
          while (!provider.isInitialized) {
            await Future.delayed(const Duration(milliseconds: 100));
          }

          if (mounted) {
            Navigator.pop(context); // Close the loading dialog

            if (provider.yourName == null || provider.yourName!.trim().isEmpty) {
              // New user account profile: Go to name and avatar creation screen
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AvatarCreationScreen()),
                (route) => false,
              );
            } else {
              // Existing user account profile: Pop back (home screen will display automatically)
              Navigator.pop(context);
            }
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid recovery code. Please check and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Recover Existing\nRelationship Workspace',
                      style: AppTypography.cormorant(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter your recovery code to restore your shared workspace, settings, and memories.',
                      style: AppTypography.spectral(
                        fontSize: 16,
                        color: theme.textColor.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: theme.isDark ? 0.08 : 0.65),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: theme.isDark ? 0.15 : 0.45),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RECOVERY CODE',
                                style: AppTypography.caption(
                                  color: theme.textColor.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _codeController,
                                textCapitalization: TextCapitalization.characters,
                                style: AppTypography.body(
                                  color: theme.textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: theme.textColor.withValues(alpha: 0.04),
                                  prefixIcon: Icon(
                                    Icons.key_rounded,
                                    color: theme.textColor.withValues(alpha: 0.5),
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      Icons.paste_rounded,
                                      color: theme.accentColor,
                                      size: 20,
                                    ),
                                    tooltip: 'Paste recovery code',
                                    onPressed: () async {
                                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                                      if (data?.text != null) {
                                        _codeController.text = data!.text!.trim().toUpperCase();
                                        setState(() {
                                          _errorMessage = null;
                                        });
                                      }
                                    },
                                  ),
                                  hintText: 'e.g. ABC123-RVT7-H9MK-PQ82-JXW5',
                                  hintStyle: AppTypography.body(
                                    color: theme.textColor.withValues(alpha: 0.3),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: theme.textColor.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: theme.accentColor,
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Recovery code is required';
                                  }
                                  if (!value.contains('-')) {
                                    return 'Invalid format. Code must contain a hyphen';
                                  }
                                  return null;
                                },
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage!,
                                  style: AppTypography.caption(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRecover,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.accentColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: theme.accentColor.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Recover Workspace',
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
      ),
    );
  }
}
