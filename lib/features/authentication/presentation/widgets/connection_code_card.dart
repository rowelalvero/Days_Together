import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The animated code-display card on [CreateCoupleCodeScreen]. Extracted
/// from its inline `build()` (Migration audit item 6) -- [animController]
/// stays owned by the screen's State, since its lifecycle (creation,
/// `forward()`, disposal) is tied to `initState`/`dispose`.
class ConnectionCodeCard extends StatelessWidget {
  const ConnectionCodeCard({
    super.key,
    required this.animController,
    required this.codeToDisplay,
    required this.theme,
  });

  final AnimationController animController;
  final String codeToDisplay;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: animController, curve: Curves.elasticOut),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.accentColor.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.accentColor.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            if (codeToDisplay.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(),
              )
            else
              // Scales down rather than wrapping: 8-character codes at this
              // size are wider than a narrow phone's card.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  codeToDisplay,
                  maxLines: 1,
                  style: AppTypography.body(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: theme.textColor,
                  ).copyWith(letterSpacing: 10),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              '⏱️ Code changes every 20 mins while waiting to connect.',
              style: AppTypography.caption(
                fontSize: 12,
                color: theme.textColor.withValues(alpha: 0.6),
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
