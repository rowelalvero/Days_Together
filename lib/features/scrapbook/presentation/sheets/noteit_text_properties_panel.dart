import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:days_together/features/scrapbook/presentation/color_picker_dialog.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/utils/canvas_mapping.dart';

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

/// Rich text properties sheet for styling text drawables (font choice, text color,
/// background highlight box, bold/italic/underline, and text alignment).
class NoteitTextPropertiesPanel extends StatelessWidget {
  final LoveStoryTheme theme;
  final TextDrawable? selectedText;
  final String activeFontFamily;
  final List<String> fontFamilies;
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
    required this.onTextColorChanged,
    required this.onHighlightColorChanged,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onToggleUnderline,
    required this.onAlignmentChanged,
  });

  IconData _getAlignIcon(TextAlign align) {
    switch (align) {
      case TextAlign.left:
        return Icons.format_align_left_rounded;
      case TextAlign.right:
        return Icons.format_align_right_rounded;
      case TextAlign.center:
      default:
        return Icons.format_align_center_rounded;
    }
  }

  TextAlign _getNextAlign(TextAlign align) {
    switch (align) {
      case TextAlign.left:
        return TextAlign.center;
      case TextAlign.center:
        return TextAlign.right;
      case TextAlign.right:
      default:
        return TextAlign.left;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool textIsBold = selectedText != null
        ? (selectedText!.style.fontWeight == FontWeight.bold)
        : isBold;
    final bool textIsItalic = selectedText != null
        ? (selectedText!.style.fontStyle == FontStyle.italic)
        : isItalic;
    final bool textIsUnderline = selectedText != null
        ? (selectedText!.style.decoration == TextDecoration.underline)
        : isUnderline;
    final Color activeColor = selectedText != null
        ? (selectedText!.style.color ?? brushColor)
        : brushColor;
    final Color activeHighlight = selectedText != null
        ? (selectedText!.style.backgroundColor ?? Colors.transparent)
        : highlightColor;
    final TextAlign activeAlign = (selectedText != null && selectedText is CustomTextDrawable)
        ? (selectedText as CustomTextDrawable).textAlign
        : textAlign;

    String matchedFont = activeFontFamily;
    if (selectedText != null && selectedText!.style.fontFamily != null) {
      final family = selectedText!.style.fontFamily!
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Font Family selector list
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: fontFamilies.length,
              itemBuilder: (ctx, idx) {
                final font = fontFamilies[idx];
                final isSelected = matchedFont == font;

                TextStyle fontStyle = const TextStyle();
                try {
                  fontStyle = GoogleFonts.getFont(
                    font,
                    color: isSelected ? theme.accentColor : theme.textColor.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  );
                } catch (_) {
                  fontStyle = TextStyle(
                    fontFamily: font,
                    color: isSelected ? theme.accentColor : theme.textColor.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(font, style: fontStyle),
                    selected: isSelected,
                    selectedColor: theme.accentColor.withValues(alpha: 0.15),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: isSelected ? theme.accentColor : theme.textColor.withValues(alpha: 0.15),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    onSelected: (selected) {
                      if (selected) {
                        onFontFamilyChanged(font);
                        if (selectedText != null) {
                          final updated = selectedText!.copyWith(
                            style: getNoteitTextStyle(
                              fontSize: selectedText!.style.fontSize ?? 20.0,
                              color: selectedText!.style.color ?? brushColor,
                              isBold: selectedText!.style.fontWeight == FontWeight.bold,
                              isItalic: selectedText!.style.fontStyle == FontStyle.italic,
                              isUnderline: selectedText!.style.decoration == TextDecoration.underline,
                              fontFamily: font,
                              highlightColor: activeHighlight,
                            ),
                          );
                          controller.replaceDrawable(selectedText!, updated);
                          controller.selectObjectDrawable(updated);
                        }
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Row 2: Text Color Selection
          Row(
            children: [
              Text(
                'Text:',
                style: AppTypography.body(
                  color: theme.textColor,
                  fontSize: 12,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: paletteColors.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == paletteColors.length) {
                        return GestureDetector(
                          onTap: () async {
                            final pickedColor = await showDialog<Color>(
                              context: context,
                              builder: (ctx2) => ColorPickerDialog(
                                initialColor: activeColor,
                                theme: theme,
                              ),
                            );
                            if (pickedColor != null) {
                              onTextColorChanged(pickedColor);
                              if (selectedText != null) {
                                final updated = selectedText!.copyWith(
                                  style: getNoteitTextStyle(
                                    fontSize: selectedText!.style.fontSize ?? 20.0,
                                    color: pickedColor,
                                    isBold: selectedText!.style.fontWeight == FontWeight.bold,
                                    isItalic: selectedText!.style.fontStyle == FontStyle.italic,
                                    isUnderline: selectedText!.style.decoration == TextDecoration.underline,
                                    fontFamily: matchedFont,
                                    highlightColor: activeHighlight,
                                  ),
                                );
                                controller.replaceDrawable(selectedText!, updated);
                                controller.selectObjectDrawable(updated);
                              }
                            }
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.textColor.withValues(alpha: 0.3),
                                width: 1.2,
                              ),
                              gradient: const SweepGradient(
                                colors: [
                                  Colors.red,
                                  Colors.yellow,
                                  Colors.green,
                                  Colors.blue,
                                  Colors.red,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: theme.textColor,
                              size: 16,
                            ),
                          ),
                        );
                      }

                      final color = paletteColors[i];
                      final isSelected = activeColor.toARGB32() == color.toARGB32();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            onTextColorChanged(color);
                            if (selectedText != null) {
                              final updated = selectedText!.copyWith(
                                style: getNoteitTextStyle(
                                  fontSize: selectedText!.style.fontSize ?? 20.0,
                                  color: color,
                                  isBold: selectedText!.style.fontWeight == FontWeight.bold,
                                  isItalic: selectedText!.style.fontStyle == FontStyle.italic,
                                  isUnderline: selectedText!.style.decoration == TextDecoration.underline,
                                  fontFamily: matchedFont,
                                  highlightColor: activeHighlight,
                                ),
                              );
                              controller.replaceDrawable(selectedText!, updated);
                              controller.selectObjectDrawable(updated);
                            }
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? theme.textColor : Colors.transparent,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 3: Highlight Color Selection
          Row(
            children: [
              Text(
                'Highlight:',
                style: AppTypography.body(
                  color: theme.textColor,
                  fontSize: 12,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: highlightColors.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == highlightColors.length) {
                        return GestureDetector(
                          onTap: () async {
                            final pickedColor = await showDialog<Color>(
                              context: context,
                              builder: (ctx2) => ColorPickerDialog(
                                initialColor: activeHighlight == Colors.transparent
                                    ? Colors.yellow.withValues(alpha: 0.3)
                                    : activeHighlight,
                                theme: theme,
                              ),
                            );
                            if (pickedColor != null) {
                              onHighlightColorChanged(pickedColor);
                              if (selectedText != null) {
                                final updated = selectedText!.copyWith(
                                  style: getNoteitTextStyle(
                                    fontSize: selectedText!.style.fontSize ?? 20.0,
                                    color: activeColor,
                                    isBold: selectedText!.style.fontWeight == FontWeight.bold,
                                    isItalic: selectedText!.style.fontStyle == FontStyle.italic,
                                    isUnderline: selectedText!.style.decoration == TextDecoration.underline,
                                    fontFamily: matchedFont,
                                    highlightColor: pickedColor,
                                  ),
                                );
                                controller.replaceDrawable(selectedText!, updated);
                                controller.selectObjectDrawable(updated);
                              }
                            }
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.textColor.withValues(alpha: 0.3),
                                width: 1.2,
                              ),
                              gradient: const SweepGradient(
                                colors: [
                                  Colors.red,
                                  Colors.yellow,
                                  Colors.green,
                                  Colors.blue,
                                  Colors.red,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: theme.textColor,
                              size: 16,
                            ),
                          ),
                        );
                      }

                      final color = highlightColors[i];
                      final isSelected = activeHighlight.toARGB32() == color.toARGB32();
                      final isTransparent = color == Colors.transparent;

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            onHighlightColorChanged(color);
                            if (selectedText != null) {
                              final updated = selectedText!.copyWith(
                                style: getNoteitTextStyle(
                                  fontSize: selectedText!.style.fontSize ?? 20.0,
                                  color: activeColor,
                                  isBold: selectedText!.style.fontWeight == FontWeight.bold,
                                  isItalic: selectedText!.style.fontStyle == FontStyle.italic,
                                  isUnderline: selectedText!.style.decoration == TextDecoration.underline,
                                  fontFamily: matchedFont,
                                  highlightColor: color,
                                ),
                              );
                              controller.replaceDrawable(selectedText!, updated);
                              controller.selectObjectDrawable(updated);
                            }
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isTransparent ? Colors.grey.withValues(alpha: 0.2) : color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? theme.textColor : Colors.transparent,
                                width: 1.8,
                              ),
                            ),
                            child: isTransparent
                                ? Icon(
                                    Icons.format_color_reset_rounded,
                                    size: 14,
                                    color: theme.textColor.withValues(alpha: 0.6),
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 4: Formatting controls
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.format_bold,
                  color: textIsBold ? theme.accentColor : theme.textColor.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  onToggleBold();
                  if (selectedText != null) {
                    final updated = selectedText!.copyWith(
                      style: getNoteitTextStyle(
                        fontSize: selectedText!.style.fontSize ?? 20.0,
                        color: activeColor,
                        isBold: !textIsBold,
                        isItalic: textIsItalic,
                        isUnderline: textIsUnderline,
                        fontFamily: matchedFont,
                        highlightColor: activeHighlight,
                      ),
                    );
                    controller.replaceDrawable(selectedText!, updated);
                    controller.selectObjectDrawable(updated);
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.format_italic,
                  color: textIsItalic ? theme.accentColor : theme.textColor.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  onToggleItalic();
                  if (selectedText != null) {
                    final updated = selectedText!.copyWith(
                      style: getNoteitTextStyle(
                        fontSize: selectedText!.style.fontSize ?? 20.0,
                        color: activeColor,
                        isBold: textIsBold,
                        isItalic: !textIsItalic,
                        isUnderline: textIsUnderline,
                        fontFamily: matchedFont,
                        highlightColor: activeHighlight,
                      ),
                    );
                    controller.replaceDrawable(selectedText!, updated);
                    controller.selectObjectDrawable(updated);
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.format_underlined,
                  color: textIsUnderline ? theme.accentColor : theme.textColor.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  onToggleUnderline();
                  if (selectedText != null) {
                    final updated = selectedText!.copyWith(
                      style: getNoteitTextStyle(
                        fontSize: selectedText!.style.fontSize ?? 20.0,
                        color: activeColor,
                        isBold: textIsBold,
                        isItalic: textIsItalic,
                        isUnderline: !textIsUnderline,
                        fontFamily: matchedFont,
                        highlightColor: activeHighlight,
                      ),
                    );
                    controller.replaceDrawable(selectedText!, updated);
                    controller.selectObjectDrawable(updated);
                  }
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_getAlignIcon(activeAlign), color: theme.accentColor),
                onPressed: () {
                  final nextAlign = _getNextAlign(activeAlign);
                  onAlignmentChanged(nextAlign);
                  if (selectedText != null && selectedText is CustomTextDrawable) {
                    final renderBox = controller.painterKey.currentContext?.findRenderObject() as RenderBox?;
                    final canvasWidth = renderBox?.size.width ?? 600.0;
                    final textWidth = selectedText!.getSize().width * selectedText!.scale;

                    double newX = selectedText!.position.dx;
                    const double margin = 20.0;

                    if (nextAlign == TextAlign.left) {
                      newX = (textWidth / 2) + margin;
                    } else if (nextAlign == TextAlign.center) {
                      newX = canvasWidth / 2;
                    } else if (nextAlign == TextAlign.right) {
                      newX = canvasWidth - (textWidth / 2) - margin;
                    }

                    final updated = (selectedText as CustomTextDrawable).copyWith(
                      textAlign: nextAlign,
                      position: Offset(newX, selectedText!.position.dy),
                    );
                    controller.replaceDrawable(selectedText!, updated);
                    controller.selectObjectDrawable(updated);
                  }
                },
                tooltip: 'Cycle Text Alignment',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
