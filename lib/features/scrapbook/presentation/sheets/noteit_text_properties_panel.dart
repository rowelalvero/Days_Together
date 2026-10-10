import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:days_together/features/scrapbook/presentation/widgets/color_picker_dialog.dart';
import 'package:days_together/features/scrapbook/presentation/widgets/noteit_color_swatch.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/scrapbook/domain/canvas_mapping.dart';

/// Font resolution helper for scrapbook text elements with safety fallback.
TextStyle getNoteitTextStyle({
  required double fontSize,
  required Color color,
  required bool isBold,
  required bool isItalic,
  required bool isUnderline,
  required String fontFamily,
  required Color highlightColor,
}) {
  final bg = highlightColor != Colors.transparent ? highlightColor : null;
  try {
    return GoogleFonts.getFont(
      fontFamily,
      fontSize: fontSize,
      color: color,
      backgroundColor: bg,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
    );
  } catch (_) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      color: color,
      backgroundColor: bg,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
    );
  }
}

/// Rich text properties sheet for styling text drawables (font choice, size,
/// text color, background highlight, bold/italic/underline, alignment).
///
/// Every control both updates the screen's "next text" defaults through its
/// callback and, when a text object is selected, restyles that object in
/// place.
class NoteitTextPropertiesPanel extends StatelessWidget {
  final LoveStoryTheme theme;
  final TextDrawable? selectedText;
  final String activeFontFamily;
  final List<String> fontFamilies;
  final double fontSize;
  final Color brushColor;
  final List<Color> paletteColors;
  final Color highlightColor;
  final List<Color> highlightColors;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final TextAlign textAlign;
  final PainterController controller;
  final void Function(String font) onFontFamilyChanged;
  final ValueChanged<double> onFontSizeChanged;
  final void Function(Color color) onTextColorChanged;
  final void Function(Color color) onHighlightColorChanged;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleItalic;
  final VoidCallback onToggleUnderline;
  final void Function(TextAlign align) onAlignmentChanged;

  const NoteitTextPropertiesPanel({
    super.key,
    required this.theme,
    required this.selectedText,
    required this.activeFontFamily,
    required this.fontFamilies,
    required this.fontSize,
    required this.brushColor,
    required this.paletteColors,
    required this.highlightColor,
    required this.highlightColors,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.textAlign,
    required this.controller,
    required this.onFontFamilyChanged,
    required this.onFontSizeChanged,
    required this.onTextColorChanged,
    required this.onHighlightColorChanged,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onToggleUnderline,
    required this.onAlignmentChanged,
  });

  static const _alignments = [
    (
      align: TextAlign.left,
      icon: Icons.format_align_left_rounded,
      label: 'Align left',
    ),
    (
      align: TextAlign.center,
      icon: Icons.format_align_center_rounded,
      label: 'Align center',
    ),
    (
      align: TextAlign.right,
      icon: Icons.format_align_right_rounded,
      label: 'Align right',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = selectedText;
    final style = selected?.style;
    final bool textIsBold = style != null
        ? style.fontWeight == FontWeight.bold
        : isBold;
    final bool textIsItalic = style != null
        ? style.fontStyle == FontStyle.italic
        : isItalic;
    final bool textIsUnderline = style != null
        ? style.decoration == TextDecoration.underline
        : isUnderline;
    final Color activeColor = style != null
        ? (style.color ?? brushColor)
        : brushColor;
    final Color activeHighlight = style != null
        ? (style.backgroundColor ?? Colors.transparent)
        : highlightColor;
    final double activeSize = style?.fontSize ?? fontSize;
    final TextAlign activeAlign = selected is CustomTextDrawable
        ? selected.textAlign
        : textAlign;

    String matchedFont = activeFontFamily;
    if (style?.fontFamily != null) {
      final family = style!.fontFamily!
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
      for (final f in fontFamilies) {
        final cleanF = f.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        if (family.contains(cleanF)) {
          matchedFont = f;
          break;
        }
      }
    }

    /// Restyles the selected text object (if any) with one property changed.
    void restyle({
      double? size,
      Color? color,
      bool? bold,
      bool? italic,
      bool? underline,
      String? font,
      Color? highlight,
    }) {
      if (selected == null) return;
      final updated = selected.copyWith(
        style: getNoteitTextStyle(
          fontSize: size ?? activeSize,
          color: color ?? activeColor,
          isBold: bold ?? textIsBold,
          isItalic: italic ?? textIsItalic,
          isUnderline: underline ?? textIsUnderline,
          fontFamily: font ?? matchedFont,
          highlightColor: highlight ?? activeHighlight,
        ),
      );
      controller.replaceDrawable(selected, updated);
      controller.selectObjectDrawable(updated);
    }

    void setAlignment(TextAlign nextAlign) {
      onAlignmentChanged(nextAlign);
      if (selected is! CustomTextDrawable) return;
      final renderBox =
          controller.painterKey.currentContext?.findRenderObject()
              as RenderBox?;
      final canvasWidth = renderBox?.size.width ?? 600.0;
      final textWidth = selected.getSize().width * selected.scale;
      const double margin = 20.0;
      final newX = switch (nextAlign) {
        TextAlign.left => (textWidth / 2) + margin,
        TextAlign.right => canvasWidth - (textWidth / 2) - margin,
        _ => canvasWidth / 2,
      };
      final updated = selected.copyWith(
        textAlign: nextAlign,
        position: Offset(newX, selected.position.dy),
      );
      controller.replaceDrawable(selected, updated);
      controller.selectObjectDrawable(updated);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
      decoration: noteitPanelDecoration(theme),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Font family, each chip previewed in its own face
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: fontFamilies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (ctx, idx) {
                final font = fontFamilies[idx];
                final isSelected = matchedFont == font;
                final chipColor = isSelected
                    ? theme.accentColor
                    : theme.textColor.withValues(alpha: 0.85);
                TextStyle fontStyle;
                try {
                  fontStyle = GoogleFonts.getFont(
                    font,
                    color: chipColor,
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  );
                } catch (_) {
                  fontStyle = TextStyle(
                    fontFamily: font,
                    color: chipColor,
                    fontSize: 14,
                  );
                }

                return ChoiceChip(
                  label: Text(font, style: fontStyle),
                  selected: isSelected,
                  selectedColor: theme.accentColor.withValues(alpha: 0.15),
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: isSelected
                        ? theme.accentColor
                        : theme.textColor.withValues(alpha: 0.18),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  onSelected: (picked) {
                    if (!picked) return;
                    onFontFamilyChanged(font);
                    restyle(font: font);
                  },
                );
              },
            ),
          ),

          // Size
          Row(
            children: [
              NoteitPanelLabel('Size', theme: theme),
              Expanded(
                child: Slider(
                  value: activeSize.clamp(10.0, 80.0),
                  min: 10.0,
                  max: 80.0,
                  label: activeSize.round().toString(),
                  semanticFormatterCallback: (v) => 'Text size ${v.round()}',
                  activeColor: theme.accentColor,
                  inactiveColor: theme.textColor.withValues(alpha: 0.15),
                  onChanged: (val) {
                    onFontSizeChanged(val);
                    restyle(size: val);
                  },
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${activeSize.round()}',
                  textAlign: TextAlign.center,
                  style: AppTypography.captionMono(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),

          // Text color
          _ColorRow(
            label: 'Color',
            theme: theme,
            colors: paletteColors,
            active: activeColor,
            onPicked: (color) {
              onTextColorChanged(color);
              restyle(color: color);
            },
            customInitial: activeColor,
          ),

          // Highlight color
          _ColorRow(
            label: 'Highlight',
            theme: theme,
            colors: highlightColors,
            active: activeHighlight,
            onPicked: (color) {
              onHighlightColorChanged(color);
              restyle(highlight: color);
            },
            customInitial: activeHighlight == Colors.transparent
                ? Colors.yellow.withValues(alpha: 0.3)
                : activeHighlight,
          ),

          // Formatting and alignment
          Row(
            children: [
              _FormatToggle(
                icon: Icons.format_bold_rounded,
                label: 'Bold',
                isOn: textIsBold,
                theme: theme,
                onTap: () {
                  onToggleBold();
                  restyle(bold: !textIsBold);
                },
              ),
              _FormatToggle(
                icon: Icons.format_italic_rounded,
                label: 'Italic',
                isOn: textIsItalic,
                theme: theme,
                onTap: () {
                  onToggleItalic();
                  restyle(italic: !textIsItalic);
                },
              ),
              _FormatToggle(
                icon: Icons.format_underlined_rounded,
                label: 'Underline',
                isOn: textIsUnderline,
                theme: theme,
                onTap: () {
                  onToggleUnderline();
                  restyle(underline: !textIsUnderline);
                },
              ),
              const Spacer(),
              for (final a in _alignments)
                _FormatToggle(
                  icon: a.icon,
                  label: a.label,
                  isOn: activeAlign == a.align,
                  theme: theme,
                  onTap: () => setAlignment(a.align),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.theme,
    required this.colors,
    required this.active,
    required this.onPicked,
    required this.customInitial,
  });

  final String label;
  final LoveStoryTheme theme;
  final List<Color> colors;
  final Color active;
  final ValueChanged<Color> onPicked;
  final Color customInitial;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NoteitPanelLabel(label, theme: theme),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final color in colors)
                  NoteitColorSwatch(
                    color: color,
                    theme: theme,
                    isSelected: active.toARGB32() == color.toARGB32(),
                    semanticLabel: color.a == 0
                        ? 'No ${label.toLowerCase()}'
                        : null,
                    onTap: () => onPicked(color),
                  ),
                NoteitCustomColorButton(
                  theme: theme,
                  onTap: () async {
                    final pickedColor = await showDialog<Color>(
                      context: context,
                      builder: (ctx2) => ColorPickerDialog(
                        initialColor: customInitial,
                        theme: theme,
                      ),
                    );
                    if (pickedColor != null) onPicked(pickedColor);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FormatToggle extends StatelessWidget {
  const _FormatToggle({
    required this.icon,
    required this.label,
    required this.isOn,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isOn;
  final LoveStoryTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: label,
      isSelected: isOn,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      style: IconButton.styleFrom(
        backgroundColor: isOn
            ? theme.accentColor.withValues(alpha: 0.18)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radii.sm + 2),
        ),
      ),
      icon: Icon(
        icon,
        size: 22,
        color: isOn
            ? theme.accentColor
            : theme.textColor.withValues(alpha: 0.75),
      ),
    );
  }
}
