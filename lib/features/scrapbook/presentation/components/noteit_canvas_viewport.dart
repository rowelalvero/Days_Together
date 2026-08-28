import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:days_together/features/scrapbook/presentation/raster_canvas.dart';
import 'package:days_together/features/scrapbook/presentation/sheets/noteit_text_properties_panel.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/utils/canvas_mapping.dart';

/// Interactive workspace wrapping the multi-layer RasterCanvas, inline text
/// editing overlays, floating selected-object controls, font size sliders, and send buttons.
class NoteitCanvasViewport extends StatelessWidget {
  final PainterController controller;
  final LoveStoryTheme theme;
  final bool isInlineEditing;
  final TextEditingController inlineTextController;
  final FocusNode inlineTextFocusNode;
  final VoidCallback onFinishInlineEditing;
  final VoidCallback onCancelInlineEditing;
  final double fontSize;
  final Color brushColor;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String activeFontFamily;
  final Color highlightColor;
  final TextAlign textAlign;
  final bool isPropertiesPanelExpanded;
  final String activeMode;
  final bool isSaving;
  final VoidCallback onSendCanvas;
  final VoidCallback onDeselect;
  final void Function(CustomTextDrawable) onStartInlineEditing;
  final void Function(ObjectDrawable) onDuplicateSelected;
  final void Function(Drawable) onBringForward;
  final void Function(Drawable) onSendBackward;
  final ValueChanged<double> onFontSizeChanged;
  final Widget bottomConfigurationSheets;

  const NoteitCanvasViewport({
    super.key,
    required this.controller,
    required this.theme,
    required this.isInlineEditing,
    required this.inlineTextController,
    required this.inlineTextFocusNode,
    required this.onFinishInlineEditing,
    required this.onCancelInlineEditing,
    required this.fontSize,
    required this.brushColor,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.activeFontFamily,
    required this.highlightColor,
    required this.textAlign,
    required this.isPropertiesPanelExpanded,
    required this.activeMode,
    required this.isSaving,
    required this.onSendCanvas,
    required this.onDeselect,
    required this.onStartInlineEditing,
    required this.onDuplicateSelected,
    required this.onBringForward,
    required this.onSendBackward,
    required this.onFontSizeChanged,
    required this.bottomConfigurationSheets,
  });

  @override
  Widget build(BuildContext context) {
    final selectedObj = controller.value.selectedObjectDrawable;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (isInlineEditing) return;
        onDeselect();
      },
      child: Stack(
        children: [
          // The Infinite Canvas
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          RasterCanvas(controller: controller),
                          if (isInlineEditing) ...[
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: onFinishInlineEditing,
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(
                                    sigmaX: 3.0,
                                    sigmaY: 3.0,
                                  ),
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: TextField(
                                  controller: inlineTextController,
                                  focusNode: inlineTextFocusNode,
                                  autofocus: true,
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  textAlign: textAlign,
                                  cursorColor: brushColor,
                                  style: getNoteitTextStyle(
                                    fontSize: fontSize,
                                    color: brushColor,
                                    isBold: isBold,
                                    isItalic: isItalic,
                                    isUnderline: isUnderline,
                                    fontFamily: activeFontFamily,
                                    highlightColor: highlightColor,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: '',
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.check_circle_rounded,
                                  size: 28,
                                  color: Colors.greenAccent,
                                ),
                                onPressed: onFinishInlineEditing,
                                tooltip: 'Save Text',
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.cancel_rounded,
                                  size: 28,
                                  color: Colors.redAccent,
                                ),
                                onPressed: onCancelInlineEditing,
                                tooltip: 'Cancel',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Floating Selected Object toolbar
          if (selectedObj != null)
            Positioned(
              top: 10,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          selectedObj.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                          color: theme.textColor,
                        ),
                        onPressed: () {
                          final updated = selectedObj.copyWith(locked: !selectedObj.locked);
                          controller.replaceDrawable(selectedObj, updated);
                          controller.selectObjectDrawable(updated);
                        },
                        tooltip: selectedObj.locked ? 'Unlock Object' : 'Lock Object',
                      ),
                      IconButton(
                        icon: Icon(Icons.flip_to_back_rounded, color: theme.textColor),
                        onPressed: () => onSendBackward(selectedObj),
                        tooltip: 'Send Backward',
                      ),
                      IconButton(
                        icon: Icon(Icons.flip_to_front_rounded, color: theme.textColor),
                        onPressed: () => onBringForward(selectedObj),
                        tooltip: 'Bring Forward',
                      ),
                      if (selectedObj is TextDrawable)
                        IconButton(
                          icon: Icon(Icons.edit_rounded, color: theme.textColor),
                          onPressed: () {
                            if (selectedObj is CustomTextDrawable) {
                              onStartInlineEditing(selectedObj as CustomTextDrawable);
                            }
                          },
                          tooltip: 'Edit Text Content',
                        ),
                      IconButton(
                        icon: Icon(Icons.copy_rounded, color: theme.textColor),
                        onPressed: () => onDuplicateSelected(selectedObj),
                        tooltip: 'Duplicate',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          controller.removeDrawable(selectedObj);
                          controller.deselectObjectDrawable();
                        },
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Floating Send Button
          Positioned(
            bottom: 110,
            right: 20,
            child: GestureDetector(
              onTap: () {},
              child: FloatingActionButton.extended(
                onPressed: isSaving ? null : onSendCanvas,
                backgroundColor: theme.accentColor,
                elevation: 4,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  'Send',
                  style: AppTypography.body(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Floating Font Size Slider (Only visible when adding/editing text)
          if (isPropertiesPanelExpanded && (activeMode == 'text' || selectedObj is TextDrawable))
            Positioned(
              left: 12,
              top: 160,
              bottom: 290,
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.text_fields_rounded, color: theme.textColor, size: 16),
                      const SizedBox(height: 4),
                      Text(
                        '${(selectedObj is TextDrawable ? (selectedObj.style.fontSize ?? fontSize) : fontSize).round()}',
                        style: AppTypography.body(
                          color: theme.textColor,
                          fontSize: 10,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value: selectedObj is TextDrawable
                                ? (selectedObj.style.fontSize ?? fontSize)
                                : fontSize,
                            min: 10.0,
                            max: 80.0,
                            activeColor: theme.accentColor,
                            inactiveColor: theme.textColor.withValues(alpha: 0.1),
                            onChanged: (val) {
                              onFontSizeChanged(val);
                              if (selectedObj is TextDrawable) {
                                final updated = selectedObj.copyWith(
                                  style: selectedObj.style.copyWith(fontSize: val),
                                );
                                controller.replaceDrawable(selectedObj, updated);
                                controller.selectObjectDrawable(updated);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Configuration Sheets
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {},
              child: bottomConfigurationSheets,
            ),
          ),
        ],
      ),
    );
  }
}
