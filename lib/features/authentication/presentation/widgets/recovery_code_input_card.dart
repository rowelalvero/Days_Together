import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/authentication/presentation/widgets/auth_page_frame.dart';

/// The recovery-code field on [RecoverRelationshipScreen]: a monospace input
/// that upper-cases as you type and only accepts code characters, a paste
/// button, and -- when the server rejects the code -- an announced error
/// with what to try next. The code, validation, and error state stay owned by
/// the screen's State.
class RecoveryCodeInputCard extends StatelessWidget {
  const RecoveryCodeInputCard({
    super.key,
    required this.controller,
    required this.errorMessage,
    required this.onEdited,
    required this.onSubmitted,
    required this.theme,
  });

  final TextEditingController controller;

  /// A server-side failure (wrong code, lockout), shown below the field.
  final String? errorMessage;

  /// Any edit or paste -- the screen clears a stale [errorMessage].
  final VoidCallback onEdited;
  final VoidCallback onSubmitted;
  final LoveStoryTheme theme;

  static const example = 'ABC123-RVT7-H9MK-PQ82-JXW5';

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) return;
    controller.text = _clean(text);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    onEdited();
  }

  static String _clean(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '');

  @override
  Widget build(BuildContext context) {
    final error = theme.semantic.error;
    OutlineInputBorder border(Color color, [double width = 1.5]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.radii.md - 2),
          borderSide: BorderSide(color: color, width: width),
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: authCardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECOVERY CODE',
            style: AppTypography.caption(
              color: theme.textColor.withValues(alpha: 0.75),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ).copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controller,
            onChanged: (_) => onEdited(),
            onFieldSubmitted: (_) => onSubmitted(),
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.visiblePassword,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: const [_RecoveryCodeFormatter()],
            style: AppTypography.bodyMono(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ).copyWith(letterSpacing: 0.5),
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white,
              prefixIcon: Icon(
                Icons.key_rounded,
                color: theme.textColor.withValues(alpha: 0.6),
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.content_paste_rounded,
                  color: theme.textColor.withValues(alpha: 0.8),
                  size: 20,
                ),
                tooltip: 'Paste recovery code',
                onPressed: _handlePaste,
              ),
              hintText: 'XXXXXX-XXXX-XXXX-XXXX-XXXX',
              hintStyle: AppTypography.bodyMono(
                color: theme.textColor.withValues(alpha: 0.4),
                fontSize: 14,
              ),
              errorStyle: AppTypography.body(color: error, fontSize: 13),
              errorMaxLines: 3,
              border: border(theme.textColor.withValues(alpha: 0.18)),
              enabledBorder: border(
                errorMessage != null
                    ? error
                    : theme.textColor.withValues(alpha: 0.18),
              ),
              focusedBorder: border(theme.accentColor, 2),
              errorBorder: border(error),
              focusedErrorBorder: border(error, 2),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            validator: (value) {
              final code = value?.trim() ?? '';
              if (code.isEmpty) return 'Recovery code is required';
              if (!code.contains('-')) {
                return 'That doesn\'t look like a recovery code. It has '
                    'dashes, like $example.';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          Text(
            'It\'s the code you were asked to save when you created your '
            'workspace. Capitals don\'t matter.',
            style: AppTypography.body(
              fontSize: 13,
              color: theme.textColor.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: errorMessage!, theme: theme),
          ],
        ],
      ),
    );
  }
}

/// A server rejection, announced to screen readers, with the next step.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.theme});

  final String message;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    final error = theme.semantic.error;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(theme.radii.sm + 4),
          border: Border.all(color: error.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: AppTypography.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check for typos. If your partner is still signed in, '
                    'they can make a new recovery code from the '
                    'Relationship profile.',
                    style: AppTypography.body(
                      fontSize: 13,
                      color: theme.textColor.withValues(alpha: 0.75),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Upper-cases and keeps only the characters a recovery code can contain,
/// moving the cursor back by however many characters before it were dropped.
class _RecoveryCodeFormatter extends TextInputFormatter {
  const _RecoveryCodeFormatter();

  static String _keep(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = _keep(newValue.text);
    final cursor = newValue.selection.isValid
        ? _keep(
            newValue.text.substring(0, newValue.selection.extentOffset),
          ).length
        : text.length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}
