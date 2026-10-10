import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The "#RRGGBB" text field in the custom theme designer. Extracted from
/// `_CustomThemeDesignerState._buildHexInput` (Migration audit item 6) --
/// [controller]'s lifecycle stays owned by the designer's State, same as
/// before the extraction.
///
/// Only hex digits can be typed, and an incomplete code shows an inline
/// error instead of being silently ignored.
class HexColorInput extends StatefulWidget {
  const HexColorInput({
    super.key,
    required this.controller,
    required this.theme,
    required this.onColorSubmitted,
  });

  final TextEditingController controller;
  final LoveStoryTheme theme;
  final ValueChanged<int> onColorSubmitted;

  @override
  State<HexColorInput> createState() => _HexColorInputState();
}

class _HexColorInputState extends State<HexColorInput> {
  String? _error;

  void _submit() {
    final hex = widget.controller.text.trim();
    final colorInt = hex.length == 6 ? int.tryParse('FF$hex', radix: 16) : null;
    if (colorInt == null) {
      setState(() => _error = 'Use 6 hex digits, like FF4D6D');
      return;
    }
    setState(() => _error = null);
    widget.onColorSubmitted(colorInt);
    widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassContainer(
          borderRadius: 18,
          opacity: 0.06,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                '#',
                style: AppTypography.bodyMono(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  style: AppTypography.bodyMono(
                    fontSize: 14,
                    color: theme.textColor,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                  ],
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Enter hex (e.g. FF4D6D)',
                    hintStyle: AppTypography.bodyMono(
                      fontSize: 14,
                      color: theme.textColor.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                  ),
                  maxLength: 6,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _submit(),
                ),
              ),
              IconButton(
                onPressed: _submit,
                tooltip: 'Apply hex color',
                icon: Icon(
                  Icons.check_circle_rounded,
                  color: theme.accentColor,
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: theme.semantic.error,
                ),
                const SizedBox(width: 6),
                Text(
                  _error!,
                  style: AppTypography.caption(
                    fontSize: 12,
                    color: theme.semantic.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
