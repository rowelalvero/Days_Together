import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// The glassmorphic "RECOVERY CODE" input card on
/// [RecoverRelationshipScreen]. Extracted from its inline `build()`
/// (Migration audit item 6) -- the code itself, the form validation, and
/// the error-message state all stay owned by the screen's State.
class RecoveryCodeInputCard extends StatelessWidget {
  const RecoveryCodeInputCard({
    super.key,
    required this.controller,
    required this.errorMessage,
    required this.onPasted,
    required this.theme,
  });

  final TextEditingController controller;
  final String? errorMessage;
  final VoidCallback onPasted;
  final LoveStoryTheme theme;

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      controller.text = data!.text!.trim().toUpperCase();
      onPasted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
                controller: controller,
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
                    onPressed: _handlePaste,
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
                    borderSide: BorderSide(color: theme.accentColor, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Colors.redAccent,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
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
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
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
    );
  }
}
