import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/authentication/presentation/widgets/primary_action_button.dart';

/// The "Recover Workspace" submit button on [RecoverRelationshipScreen].
class RecoverButton extends StatelessWidget {
  const RecoverButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.theme,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) => PrimaryActionButton(
    label: 'Recover Workspace',
    loadingLabel: 'Checking code…',
    isLoading: isLoading,
    onPressed: onPressed,
    theme: theme,
  );
}
