import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/authentication/presentation/widgets/primary_action_button.dart';

/// The "Continue" call to action on [CreateCoupleCodeScreen] and
/// [GenesisScreen].
class ContinueButton extends StatelessWidget {
  const ContinueButton({
    super.key,
    required this.onPressed,
    required this.theme,
  });

  final VoidCallback? onPressed;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) => PrimaryActionButton(
    label: 'Continue',
    icon: Icons.arrow_forward_rounded,
    onPressed: onPressed,
    theme: theme,
  );
}
