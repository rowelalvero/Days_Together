import 'package:flutter/material.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/themes/app_typography.dart';

class TextOverlayWidget extends StatefulWidget {
  final CanvasTextOverlay overlay;
  final Function(CanvasTextOverlay updated) onUpdate;
  final VoidCallback onTap;

  const TextOverlayWidget({
    super.key,
    required this.overlay,
    required this.onUpdate,
    required this.onTap,
  });

  @override
  State<TextOverlayWidget> createState() => _TextOverlayWidgetState();
}

class _TextOverlayWidgetState extends State<TextOverlayWidget> {
  late double _startScale;

  @override
  Widget build(BuildContext context) {
    final style = widget.overlay;

    final textStyle = AppTypography.lora(
      fontSize: style.fontSize,
      fontWeight: style.isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: style.isItalic ? FontStyle.italic : FontStyle.normal,
      color: Color(style.color),
    ).copyWith(
      decoration: style.isUnderline ? TextDecoration.underline : TextDecoration.none,
    );

    final alignment = style.alignment == 'left'
        ? TextAlign.left
        : style.alignment == 'right'
            ? TextAlign.right
            : TextAlign.center;

    return Positioned(
      left: style.x,
      top: style.y,
      child: GestureDetector(
        onScaleStart: (details) {
          _startScale = style.scale;
        },
        onScaleUpdate: (details) {
          // 1. Drag handling (single finger or focal point delta)
          double newX = style.x + details.focalPointDelta.dx;
          double newY = style.y + details.focalPointDelta.dy;

          // 2. Scale handling (two fingers pinching)
          double newScale = style.scale;
          if (details.pointerCount > 1) {
            newScale = (_startScale * details.scale).clamp(0.5, 4.0);
          }

          widget.onUpdate(
            CanvasTextOverlay(
              id: style.id,
              text: style.text,
              x: newX,
              y: newY,
              scale: newScale,
              fontSize: style.fontSize,
              color: style.color,
              backgroundColor: style.backgroundColor,
              isBold: style.isBold,
              isItalic: style.isItalic,
              isUnderline: style.isUnderline,
              alignment: style.alignment,
            ),
          );
        },
        onDoubleTap: widget.onTap,
        onTap: widget.onTap, // Support single tap for edit as well
        child: Transform.scale(
          scale: style.scale,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: style.backgroundColor == 0
                  ? Colors.transparent
                  : Color(style.backgroundColor),
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              style.text,
              textAlign: alignment,
              style: textStyle,
            ),
          ),
        ),
      ),
    );
  }
}
