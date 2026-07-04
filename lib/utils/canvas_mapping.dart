import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:days_together/models/canvas_document.dart';
import 'package:days_together/widgets/custom_backgrounds.dart';

class CanvasMapping {
  static CanvasDocument toDocument(List<Drawable> drawables, BackgroundDrawable? background) {
    final List<CanvasObject> objects = [];
    
    BackgroundData bgData = const BackgroundData(type: 'color', color: 0xFFFFFFFF);
    if (background is ColorBackgroundDrawable) {
      bgData = BackgroundData(type: 'color', color: background.color.toARGB32());
    } else if (background is GradientBackgroundDrawable) {
      bgData = BackgroundData(
        type: 'gradient',
        gradientColors: background.colors.map((c) => c.toARGB32()).toList(),
      );
    } else if (background is GridBackgroundDrawable) {
      bgData = BackgroundData(
        type: 'grid',
        color: background.backgroundColor.toARGB32(),
        step: background.step,
      );
    } else if (background is DotsBackgroundDrawable) {
      bgData = BackgroundData(
        type: 'dots',
        color: background.backgroundColor.toARGB32(),
        step: background.step,
      );
    } else if (background is NotebookBackgroundDrawable) {
      bgData = BackgroundData(
        type: 'notebook',
        color: background.backgroundColor.toARGB32(),
        step: background.step,
      );
    }

    for (int i = 0; i < drawables.length; i++) {
      final d = drawables[i];
      final id = 'obj_${DateTime.now().microsecondsSinceEpoch}_$i';
      
      if (d is FreeStyleDrawable) {
        objects.add(StrokeObject(
          id: id,
          x: 0,
          y: 0,
          scale: 1,
          rotation: 0,
          points: d.path.map((p) => CanvasPoint(p.dx, p.dy)).toList(),
          strokeWidth: d.strokeWidth,
          color: d.color.toARGB32(),
          isEraser: false,
        ));
      } else if (d is EraseDrawable) {
        objects.add(StrokeObject(
          id: id,
          x: 0,
          y: 0,
          scale: 1,
          rotation: 0,
          points: d.path.map((p) => CanvasPoint(p.dx, p.dy)).toList(),
          strokeWidth: d.strokeWidth,
          color: 0,
          isEraser: true,
        ));
      } else if (d is TextDrawable) {
        objects.add(TextObject(
          id: id,
          x: d.position.dx,
          y: d.position.dy,
          scale: d.scale,
          rotation: d.rotationAngle,
          text: d.text,
          color: d.style.color?.toARGB32() ?? 0xFF000000,
          fontSize: d.style.fontSize ?? 14.0,
          fontFamily: d.style.fontFamily ?? 'Spectral',
          backgroundColor: d.style.backgroundColor?.toARGB32() ?? 0,
          isBold: d.style.fontWeight == FontWeight.bold,
          isItalic: d.style.fontStyle == FontStyle.italic,
          isUnderline: d.style.decoration == TextDecoration.underline,
          locked: d.locked,
          hidden: d.hidden,
        ));
      } else if (d is ImageDrawable) {
        objects.add(ImageObject(
          id: id,
          x: d.position.dx,
          y: d.position.dy,
          scale: d.scale,
          rotation: d.rotationAngle,
          imagePath: '', 
          locked: d.locked,
          hidden: d.hidden,
        ));
      } else if (d is RectangleDrawable) {
        objects.add(ShapeObject(
          id: id,
          x: d.position.dx,
          y: d.position.dy,
          scale: d.scale,
          rotation: d.rotationAngle,
          shapeType: 'rectangle',
          width: d.size.width,
          height: d.size.height,
          color: d.paint.color.toARGB32(),
          strokeWidth: d.paint.strokeWidth,
          isFilled: d.paint.style == PaintingStyle.fill,
          locked: d.locked,
          hidden: d.hidden,
        ));
      } else if (d is OvalDrawable) {
        objects.add(ShapeObject(
          id: id,
          x: d.position.dx,
          y: d.position.dy,
          scale: d.scale,
          rotation: d.rotationAngle,
          shapeType: 'oval',
          width: d.size.width,
          height: d.size.height,
          color: d.paint.color.toARGB32(),
          strokeWidth: d.paint.strokeWidth,
          isFilled: d.paint.style == PaintingStyle.fill,
          locked: d.locked,
          hidden: d.hidden,
        ));
      } else if (d is LineDrawable) {
        objects.add(ShapeObject(
          id: id,
          x: d.position.dx,
          y: d.position.dy,
          scale: d.scale,
          rotation: d.rotationAngle,
          shapeType: 'line',
          width: d.length,
          height: 0,
          color: d.paint.color.toARGB32(),
          strokeWidth: d.paint.strokeWidth,
          locked: d.locked,
          hidden: d.hidden,
        ));
      } else if (d is ArrowDrawable) {
        objects.add(ShapeObject(
          id: id,
          x: d.position.dx,
          y: d.position.dy,
          scale: d.scale,
          rotation: d.rotationAngle,
          shapeType: 'arrow',
          width: d.length,
          height: 0,
          color: d.paint.color.toARGB32(),
          strokeWidth: d.paint.strokeWidth,
          locked: d.locked,
          hidden: d.hidden,
        ));
      }
    }

    return CanvasDocument(background: bgData, objects: objects);
  }

  static BackgroundDrawable toBackgroundDrawable(BackgroundData bgData) {
    switch (bgData.type) {
      case 'gradient':
        final colors = bgData.gradientColors?.map((c) => Color(c)).toList() ?? [Colors.white];
        return GradientBackgroundDrawable(colors: colors);
      case 'grid':
        return GridBackgroundDrawable(
          backgroundColor: bgData.color != null ? Color(bgData.color!) : Colors.white,
          step: bgData.step ?? 25.0,
        );
      case 'dots':
        return DotsBackgroundDrawable(
          backgroundColor: bgData.color != null ? Color(bgData.color!) : Colors.white,
          step: bgData.step ?? 25.0,
        );
      case 'notebook':
        return NotebookBackgroundDrawable(
          backgroundColor: bgData.color != null ? Color(bgData.color!) : const Color(0xFFF9F9FB),
          step: bgData.step ?? 30.0,
        );
      case 'color':
      default:
        return ColorBackgroundDrawable(color: bgData.color != null ? Color(bgData.color!) : Colors.white);
    }
  }

  static Future<List<Drawable>> toDrawables(CanvasDocument doc) async {
    final List<Drawable> drawables = [];
    for (final obj in doc.objects) {
      if (obj is StrokeObject) {
        if (obj.points.isEmpty) continue;
        if (obj.isEraser) {
          drawables.add(EraseDrawable(
            path: obj.points.map((p) => Offset(p.x, p.y)).toList(),
            strokeWidth: obj.strokeWidth,
            hidden: obj.hidden,
          ));
        } else {
          drawables.add(FreeStyleDrawable(
            path: obj.points.map((p) => Offset(p.x, p.y)).toList(),
            strokeWidth: obj.strokeWidth,
            color: Color(obj.color),
            hidden: obj.hidden,
          ));
        }
      } else if (obj is TextObject) {
        drawables.add(TextDrawable(
          text: obj.text,
          position: Offset(obj.x, obj.y),
          scale: obj.scale,
          rotation: obj.rotation,
          style: _getTextStyle(obj),
          locked: obj.locked,
          hidden: obj.hidden,
        ));
      } else if (obj is ShapeObject) {
        final paint = Paint()
          ..color = Color(obj.color)
          ..strokeWidth = obj.strokeWidth
          ..style = obj.isFilled ? PaintingStyle.fill : PaintingStyle.stroke;
        
        final size = Size(obj.width, obj.height);
        final pos = Offset(obj.x, obj.y);

        switch (obj.shapeType) {
          case 'rectangle':
            drawables.add(RectangleDrawable(
              paint: paint,
              size: size,
              position: pos,
              scale: obj.scale,
              rotationAngle: obj.rotation,
              locked: obj.locked,
              hidden: obj.hidden,
            ));
            break;
          case 'oval':
            drawables.add(OvalDrawable(
              paint: paint,
              size: size,
              position: pos,
              scale: obj.scale,
              rotationAngle: obj.rotation,
              locked: obj.locked,
              hidden: obj.hidden,
            ));
            break;
          case 'line':
            drawables.add(LineDrawable(
              paint: paint,
              length: obj.width,
              position: pos,
              scale: obj.scale,
              rotationAngle: obj.rotation,
              locked: obj.locked,
              hidden: obj.hidden,
            ));
            break;
          case 'arrow':
            drawables.add(ArrowDrawable(
              paint: paint,
              length: obj.width,
              position: pos,
              scale: obj.scale,
              rotationAngle: obj.rotation,
              locked: obj.locked,
              hidden: obj.hidden,
            ));
            break;
        }
      } else if (obj is ImageObject) {
        if (obj.imagePath.isNotEmpty && File(obj.imagePath).existsSync()) {
          try {
            final bytes = await File(obj.imagePath).readAsBytes();
            final uiImg = await _decodeImage(bytes);
            drawables.add(ImageDrawable(
              image: uiImg,
              position: Offset(obj.x, obj.y),
              scale: obj.scale,
              rotationAngle: obj.rotation,
              locked: obj.locked,
              hidden: obj.hidden,
            ));
          } catch (e) {
            debugPrint('CanvasMapping: Error loading local image: $e');
          }
        }
      }
    }
    return drawables;
  }

  static Future<ui.Image> _decodeImage(List<int> bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(Uint8List.fromList(bytes), (img) {
      completer.complete(img);
    });
    return completer.future;
  }

  static TextStyle _getTextStyle(TextObject obj) {
    final bg = obj.backgroundColor != 0 ? Color(obj.backgroundColor) : null;
    try {
      return GoogleFonts.getFont(
        obj.fontFamily,
        color: Color(obj.color),
        fontSize: obj.fontSize,
        backgroundColor: bg,
        fontWeight: obj.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: obj.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: obj.isUnderline ? TextDecoration.underline : TextDecoration.none,
      );
    } catch (_) {
      return TextStyle(
        color: Color(obj.color),
        fontSize: obj.fontSize,
        fontFamily: obj.fontFamily,
        backgroundColor: bg,
        fontWeight: obj.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: obj.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: obj.isUnderline ? TextDecoration.underline : TextDecoration.none,
      );
    }
  }
}
