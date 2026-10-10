import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/authentication/presentation/widgets/auth_page_frame.dart';

/// Step 1 of [CreateCoupleCodeScreen]: the pairing code, split into two
/// monospace halves so it reads aloud and copies over easily, plus its
/// Copy / Share / new-code actions. [animController] stays owned by the
/// screen's State (its lifecycle is tied to `initState`/`dispose`).
class ConnectionCodeCard extends StatelessWidget {
  const ConnectionCodeCard({
    super.key,
    required this.animController,
    required this.codeToDisplay,
    required this.copied,
    required this.onCopy,
    required this.onShare,
    required this.onNewCode,
    required this.theme,
  });

  final AnimationController animController;
  final String codeToDisplay;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onNewCode;
  final LoveStoryTheme theme;

  /// "ABCD1234" -> ["ABCD", "1234"]; short legacy codes split the same way.
  static List<String> chunks(String code) {
    if (code.length < 6) return [code];
    final mid = (code.length / 2).ceil();
    return [code.substring(0, mid), code.substring(mid)];
  }

  @override
  Widget build(BuildContext context) {
    final hasCode = codeToDisplay.isNotEmpty;
    final entrance = CurvedAnimation(
      parent: animController,
      curve: Curves.easeOutBack,
    );

    return FadeTransition(
      opacity: animController,
      child: ScaleTransition(
        scale: Tween(begin: 0.94, end: 1.0).animate(entrance),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          decoration: authCardDecoration(
            theme,
            border: theme.accentColor.withValues(alpha: 0.5),
          ),
          child: Column(
            children: [
              if (!hasCode)
                _Loading(theme: theme)
              else
                Semantics(
                  label:
                      'Connection code: ${codeToDisplay.split('').join(' ')}',
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, part) in chunks(
                          codeToDisplay,
                        ).indexed) ...[
                          if (i > 0)
                            Container(
                              width: 10,
                              height: 3,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: theme.textColor.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          Text(
                            part,
                            maxLines: 1,
                            style: AppTypography.bodyMono(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: theme.textColor,
                            ).copyWith(letterSpacing: 4),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Changes every 20 minutes until your partner joins.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        fontSize: 13,
                        color: theme.textColor.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: copied ? 'Copied' : 'Copy Code',
                      icon: copied ? Icons.check_rounded : Icons.copy_rounded,
                      filled: true,
                      onPressed: hasCode ? onCopy : null,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      label: 'Share',
                      icon: Icons.ios_share_rounded,
                      filled: false,
                      onPressed: hasCode ? onShare : null,
                      theme: theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: hasCode ? onNewCode : null,
                style: TextButton.styleFrom(
                  foregroundColor: theme.textColor.withValues(alpha: 0.8),
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Get a new code',
                  style: AppTypography.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.theme});

  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: theme.accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Getting your code…',
            style: AppTypography.body(fontSize: 15, color: theme.textColor),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onPressed,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onPressed;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(theme.radii.md - 4),
    );
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.body(fontSize: 15, fontWeight: FontWeight.w600),
    );

    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: text,
        style: FilledButton.styleFrom(
          backgroundColor: theme.accentColor,
          foregroundColor: theme.onAccentColor,
          minimumSize: const Size.fromHeight(48),
          shape: shape,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: text,
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.textColor,
        side: BorderSide(color: theme.textColor.withValues(alpha: 0.3)),
        minimumSize: const Size.fromHeight(48),
        shape: shape,
      ),
    );
  }
}
