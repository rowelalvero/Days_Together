import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/authentication/presentation/widgets/auth_input_decoration.dart';

/// The email/password/(sign-up only) confirm-password fields on
/// [AuthScreen], including their validators. Extracted from the screen's
/// `build()` (Migration audit item 6) -- state (controllers, obscure
/// flags) stays on the screen's State, matching how this app's other
/// extracted forms work.
class AuthFormFields extends StatelessWidget {
  const AuthFormFields({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isSignUp,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onTogglePasswordVisibility,
    required this.onToggleConfirmPasswordVisibility,
    required this.onSubmit,
    required this.theme,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isSignUp;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onToggleConfirmPasswordVisibility;
  final VoidCallback onSubmit;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: AppTypography.body(color: theme.textColor),
          decoration: authInputDecoration(
            label: 'Email Address',
            icon: Icons.mail_outline_rounded,
            theme: theme,
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter your email';
            }
            if (!val.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: passwordController,
          obscureText: obscurePassword,
          textInputAction: isSignUp
              ? TextInputAction.next
              : TextInputAction.done,
          onFieldSubmitted: (_) {
            if (!isSignUp) {
              onSubmit();
            }
          },
          style: AppTypography.body(color: theme.textColor),
          decoration: authInputDecoration(
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            theme: theme,
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: theme.textColor.withValues(alpha: 0.4),
              ),
              onPressed: onTogglePasswordVisibility,
            ),
          ),
          validator: (val) {
            if (val == null || val.isEmpty) {
              return 'Please enter a password';
            }
            if (val.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        if (isSignUp) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: confirmPasswordController,
            obscureText: obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            style: AppTypography.body(color: theme.textColor),
            decoration: authInputDecoration(
              label: 'Confirm Password',
              icon: Icons.lock_outline_rounded,
              theme: theme,
              suffixIcon: IconButton(
                icon: Icon(
                  obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: theme.textColor.withValues(alpha: 0.4),
                ),
                onPressed: onToggleConfirmPasswordVisibility,
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please confirm your password';
              }
              if (val != passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }
}
