import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/authentication/presentation/widgets/pill_outline_button.dart';

/// The Copy Code / Share button row on [CreateCoupleCodeScreen]. Extracted
/// from its inline `build()` (Migration audit item 6) -- the copied-flag
/// state stays on the screen, matching how this app's other extracted
/// forms keep state on their own State.
class CodeActionsRow extends StatelessWidget {
  const CodeActionsRow({
    super.key,
    required this.copied,
    required this.hasCode,
    required this.onCopy,
    required this.onShare,
    required this.theme,
  });

  final bool copied;
  final bool hasCode;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PillOutlineButton(
            label: copied ? '✓ Copied' : 'Copy Code',
            icon: Icons.copy_rounded,
            onPressed: hasCode ? onCopy : () {},
            theme: theme,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: PillOutlineButton(
            label: 'Share',
            icon: Icons.share_rounded,
            onPressed: hasCode ? onShare : () {},
            theme: theme,
          ),
        ),
      ],
    );
  }
}
