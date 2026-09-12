import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:days_together/features/authentication/presentation/widgets/auth_form_fields.dart';
import 'package:days_together/features/authentication/presentation/widgets/auth_header.dart';
import 'package:days_together/features/authentication/presentation/widgets/auth_mode_toggle.dart';
import 'package:days_together/features/authentication/presentation/widgets/auth_submit_button.dart';
import 'package:days_together/features/authentication/presentation/widgets/google_sign_in_button.dart';
import 'package:days_together/features/authentication/presentation/widgets/or_divider.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/theme/theme_controller.dart';

/// The combined sign-in/sign-up screen: email/password auth plus Google
/// sign-in.
///
/// Its ~510-line single-literal `build()` was broken into focused widgets
/// under `presentation/widgets/` (Migration audit item 6) -- this class
/// still owns the form key, text controllers, and the sign-in/sign-up/
/// loading/obscure-password flags, matching how this app's other
/// extracted forms keep state on their own State.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final session = ref.read(sessionControllerProvider.notifier);

    try {
      if (_isSignUp) {
        await session.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (mounted) {
          final theme = ref.read(themeControllerProvider).currentLoveTheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Verification link sent! Please check your email to activate your account.',
              ),
              backgroundColor: theme.accentColor,
            ),
          );
          setState(() => _isSignUp = false);
        }
      } else {
        // No explicit navigation after this: signing in flips
        // CoupleSession.userId away from null, which the router's
        // single redirect (app_router.dart) picks up via refreshListenable
        // and moves off Routes.auth (no longer a valid `unauthenticated`
        // location) to whatever stage comes next -- replacing the old
        // popUntil-to-root-and-let-AppHome-decide pattern this method's own
        // comment already described; that decision now lives in
        // appRedirect instead of AppHome.
        await session.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final session = ref.read(sessionControllerProvider.notifier);

    try {
      // Same reasoning as _submit's email sign-in above: no explicit
      // navigation needed, the redirect handles the transition.
      await session.signInWithGoogle();
    } catch (e) {
      if (e.toString() != 'Sign in aborted by user' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final theme = themeState.currentLoveTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeState.currentGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  AuthHeader(isSignUp: _isSignUp, theme: theme),
                  const SizedBox(height: 40),
                  // Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.textColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: theme.textColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthModeToggle(
                            isSignUp: _isSignUp,
                            theme: theme,
                            onChanged: (val) => setState(() => _isSignUp = val),
                          ),
                          const SizedBox(height: 24),
                          AuthFormFields(
                            emailController: _emailController,
                            passwordController: _passwordController,
                            confirmPasswordController:
                                _confirmPasswordController,
                            isSignUp: _isSignUp,
                            obscurePassword: _obscurePassword,
                            obscureConfirmPassword: _obscureConfirmPassword,
                            onTogglePasswordVisibility: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            onToggleConfirmPasswordVisibility: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                            onSubmit: _submit,
                            theme: theme,
                          ),
                          const SizedBox(height: 32),
                          AuthSubmitButton(
                            isLoading: _isLoading,
                            isSignUp: _isSignUp,
                            onPressed: _submit,
                            theme: theme,
                          ),
                          const SizedBox(height: 24),
                          OrDivider(theme: theme),
                          const SizedBox(height: 24),
                          GoogleSignInButton(
                            isLoading: _isLoading,
                            onPressed: _handleGoogleSignIn,
                            theme: theme,
                          ),
                        ],
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
}
