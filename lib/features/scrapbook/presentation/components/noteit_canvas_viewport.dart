import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:days_together/features/scrapbook/presentation/widgets/raster_canvas.dart';
import 'package:days_together/features/scrapbook/presentation/sheets/noteit_text_properties_panel.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/scrapbook/domain/canvas_mapping.dart';

/// Interactive workspace wrapping the multi-layer RasterCanvas, the inline
/// text editing overlay, the selected-object action bar, and the bottom
/// dock (property sheets + toolbar).
///
/// The canvas keeps a fixed footprint -- it is laid out against a constant
/// dock reservation, not the live height of the sheets -- because drawables
/// are positioned in canvas pixels: resizing the canvas whenever a sheet
/// opened would shift everything already drawn. Sheets float over the
/// canvas's lower edge instead and can be folded away from the toolbar.
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
  final VoidCallback onDeselect;
  final void Function(CustomTextDrawable) onStartInlineEditing;
  final void Function(ObjectDrawable) onDuplicateSelected;
  final void Function(Drawable) onBringForward;
  final void Function(Drawable) onSendBackward;
  final Widget bottomConfigurationSheets;

  /// Height kept clear below the canvas for the toolbar.
  static const double dockReservation = 76;

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
    required this.onDeselect,
    required this.onStartInlineEditing,
    required this.onDuplicateSelected,
    required this.onBringForward,
    required this.onSendBackward,
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
          // The canvas
          Positioned.fill(
            bottom: dockReservation,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(theme.radii.lg),
                    border: Border.all(
                      color: theme.textColor.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(theme.radii.lg),
                    child: Stack(
                      children: [
                        RasterCanvas(controller: controller),
                        if (isInlineEditing) ..._inlineEditor(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Selected-object action bar
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: theme.motion.fast,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: selectedObj != null && !isInlineEditing
                  ? Center(
                      key: const ValueKey('selection-bar'),
                      child: _SelectionBar(
                        selected: selectedObj,
                        controller: controller,
                        theme: theme,
                        onStartInlineEditing: onStartInlineEditing,
                        onDuplicateSelected: onDuplicateSelected,
                        onBringForward: onBringForward,
                        onSendBackward: onSendBackward,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no-selection')),
            ),
          ),

          // Bottom dock: property sheets above the toolbar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            // Absorbs taps so they don't reach the deselect handler above.
            child: GestureDetector(
              onTap: () {},
              child: bottomConfigurationSheets,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _inlineEditor() {
    return [
      Positioned.fill(
        child: GestureDetector(
          onTap: onFinishInlineEditing,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
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
            decoration: InputDecoration(
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'Write something sweet…',
              hintStyle: AppTypography.body(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: 10,
        left: 10,
        right: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _OverlayPill(
              icon: Icons.close_rounded,
              label: 'Cancel',
              background: Colors.black.withValues(alpha: 0.55),
              foreground: Colors.white,
              onTap: onCancelInlineEditing,
            ),
            _OverlayPill(
              icon: Icons.check_rounded,
              label: 'Done',
              background: theme.accentColor,
              foreground: theme.onAccentColor,
              onTap: onFinishInlineEditing,
            ),
          ],
        ),
      ),
    ];
  }
}

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.button(
                  color: foreground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selected,
    required this.controller,
    required this.theme,
    required this.onStartInlineEditing,
    required this.onDuplicateSelected,
    required this.onBringForward,
    required this.onSendBackward,
  });

  final ObjectDrawable selected;
  final PainterController controller;
  final LoveStoryTheme theme;
  final void Function(CustomTextDrawable) onStartInlineEditing;
  final void Function(ObjectDrawable) onDuplicateSelected;
  final void Function(Drawable) onBringForward;
  final void Function(Drawable) onSendBackward;

  @override
  Widget build(BuildContext context) {
    final iconColor = theme.textColor.withValues(alpha: 0.9);
    final selected = this.selected;
    return GestureDetector(
      // Absorbs taps so they don't reach the deselect handler.
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: theme.backgroundColor.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(theme.radii.pill),
          border: Border.all(color: theme.textColor.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected is CustomTextDrawable)
              IconButton(
                icon: Icon(Icons.edit_note_rounded, color: iconColor),
                onPressed: () => onStartInlineEditing(selected),
                tooltip: 'Edit text',
              ),
            IconButton(
              icon: Icon(
                selected.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: selected.locked ? theme.accentColor : iconColor,
              ),
              isSelected: selected.locked,
              onPressed: () {
                final updated = selected.copyWith(locked: !selected.locked);
                controller.replaceDrawable(selected, updated);
                controller.selectObjectDrawable(updated);
              },
              tooltip: selected.locked ? 'Unlock' : 'Lock in place',
            ),
            IconButton(
              icon: Icon(Icons.flip_to_back_rounded, color: iconColor),
              onPressed: () => onSendBackward(selected),
              tooltip: 'Send backward',
            ),
            IconButton(
              icon: Icon(Icons.flip_to_front_rounded, color: iconColor),
              onPressed: () => onBringForward(selected),
              tooltip: 'Bring forward',
            ),
            IconButton(
              icon: Icon(Icons.copy_rounded, color: iconColor),
              onPressed: () => onDuplicateSelected(selected),
              tooltip: 'Duplicate',
            ),
            Container(
              width: 1,
              height: 24,
              color: theme.textColor.withValues(alpha: 0.15),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: theme.semantic.error,
              ),
              onPressed: () {
                controller.removeDrawable(selected);
                controller.deselectObjectDrawable();
              },
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
