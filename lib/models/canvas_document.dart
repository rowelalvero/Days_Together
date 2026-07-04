import 'package:flutter/material.dart';

class CanvasPoint {
  final double x;
  final double y;
  const CanvasPoint(this.x, this.y);
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory CanvasPoint.fromJson(Map<String, dynamic> json) =>
      CanvasPoint((json['x'] as num).toDouble(), (json['y'] as num).toDouble());
}

class BackgroundData {
  final String type; // 'color', 'gradient', 'grid', 'dots', 'notebook', 'image'
  final int? color;
  final List<int>? gradientColors;
  final double? step;
  final String? imagePath;
  final String? imageUrl;

  const BackgroundData({
    required this.type,
    this.color,
    this.gradientColors,
    this.step,
    this.imagePath,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'color': color,
        'gradientColors': gradientColors,
        'step': step,
        'imagePath': imagePath,
        'imageUrl': imageUrl,
      };

  factory BackgroundData.fromJson(Map<String, dynamic> json) {
    return BackgroundData(
      type: json['type'] as String? ?? 'color',
      color: json['color'] as int?,
      gradientColors: (json['gradientColors'] as List?)?.map((c) => c as int).toList(),
      step: (json['step'] as num?)?.toDouble(),
      imagePath: json['imagePath'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

abstract class CanvasObject {
  final String id;
  final String type;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final bool locked;
  final bool hidden;

  const CanvasObject({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.locked = false,
    this.hidden = false,
  });

  Map<String, dynamic> toJson();

  factory CanvasObject.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    switch (type) {
      case 'stroke':
        return StrokeObject.fromJson(json);
      case 'text':
        return TextObject.fromJson(json);
      case 'image':
        return ImageObject.fromJson(json);
      case 'shape':
        return ShapeObject.fromJson(json);
      default:
        throw Exception('CanvasObject: Unknown type: $type');
    }
  }
}

class StrokeObject extends CanvasObject {
  final List<CanvasPoint> points;
  final double strokeWidth;
  final int color;
  final bool isEraser;

  const StrokeObject({
    required super.id,
    required super.x,
    required super.y,
    super.scale,
    super.rotation,
    super.locked,
    super.hidden,
    required this.points,
    required this.strokeWidth,
    required this.color,
    required this.isEraser,
  }) : super(type: 'stroke');

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'locked': locked,
        'hidden': hidden,
        'points': points.map((p) => p.toJson()).toList(),
        'strokeWidth': strokeWidth,
        'color': color,
        'isEraser': isEraser,
      };

  factory StrokeObject.fromJson(Map<String, dynamic> json) => StrokeObject(
        id: json['id'] as String,
        x: (json['x'] as num? ?? 0.0).toDouble(),
        y: (json['y'] as num? ?? 0.0).toDouble(),
        scale: (json['scale'] as num? ?? 1.0).toDouble(),
        rotation: (json['rotation'] as num? ?? 0.0).toDouble(),
        locked: json['locked'] as bool? ?? false,
        hidden: json['hidden'] as bool? ?? false,
        points: (json['points'] as List).map((p) => CanvasPoint.fromJson(p)).toList(),
        strokeWidth: (json['strokeWidth'] as num).toDouble(),
        color: json['color'] as int? ?? 0xFF000000,
        isEraser: json['isEraser'] as bool? ?? false,
      );
}

class TextObject extends CanvasObject {
  final String text;
  final int color;
  final double fontSize;
  final String fontFamily;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;

  const TextObject({
    required super.id,
    required super.x,
    required super.y,
    super.scale,
    super.rotation,
    super.locked,
    super.hidden,
    required this.text,
    required this.color,
    required this.fontSize,
    this.fontFamily = 'Roboto',
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
  }) : super(type: 'text');

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'locked': locked,
        'hidden': hidden,
        'text': text,
        'color': color,
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'isBold': isBold,
        'isItalic': isItalic,
        'isUnderline': isUnderline,
      };

  factory TextObject.fromJson(Map<String, dynamic> json) => TextObject(
        id: json['id'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        scale: (json['scale'] as num? ?? 1.0).toDouble(),
        rotation: (json['rotation'] as num? ?? 0.0).toDouble(),
        locked: json['locked'] as bool? ?? false,
        hidden: json['hidden'] as bool? ?? false,
        text: json['text'] as String,
        color: json['color'] as int,
        fontSize: (json['fontSize'] as num).toDouble(),
        fontFamily: json['fontFamily'] as String? ?? 'Roboto',
        isBold: json['isBold'] as bool? ?? false,
        isItalic: json['isItalic'] as bool? ?? false,
        isUnderline: json['isUnderline'] as bool? ?? false,
      );
}

class ImageObject extends CanvasObject {
  final String imagePath;
  final String? imageUrl;

  const ImageObject({
    required super.id,
    required super.x,
    required super.y,
    super.scale,
    super.rotation,
    super.locked,
    super.hidden,
    required this.imagePath,
    this.imageUrl,
  }) : super(type: 'image');

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'locked': locked,
        'hidden': hidden,
        'imagePath': imagePath,
        'imageUrl': imageUrl,
      };

  factory ImageObject.fromJson(Map<String, dynamic> json) => ImageObject(
        id: json['id'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        scale: (json['scale'] as num? ?? 1.0).toDouble(),
        rotation: (json['rotation'] as num? ?? 0.0).toDouble(),
        locked: json['locked'] as bool? ?? false,
        hidden: json['hidden'] as bool? ?? false,
        imagePath: json['imagePath'] as String,
        imageUrl: json['imageUrl'] as String?,
      );
}

class ShapeObject extends CanvasObject {
  final String shapeType; // 'rectangle', 'oval', 'line', 'arrow'
  final double width;
  final double height;
  final int color;
  final double strokeWidth;
  final bool isFilled;

  const ShapeObject({
    required super.id,
    required super.x,
    required super.y,
    super.scale,
    super.rotation,
    super.locked,
    super.hidden,
    required this.shapeType,
    required this.width,
    required this.height,
    required this.color,
    required this.strokeWidth,
    this.isFilled = false,
  }) : super(type: 'shape');

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'locked': locked,
        'hidden': hidden,
        'shapeType': shapeType,
        'width': width,
        'height': height,
        'color': color,
        'strokeWidth': strokeWidth,
        'isFilled': isFilled,
      };

  factory ShapeObject.fromJson(Map<String, dynamic> json) => ShapeObject(
        id: json['id'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        scale: (json['scale'] as num? ?? 1.0).toDouble(),
        rotation: (json['rotation'] as num? ?? 0.0).toDouble(),
        locked: json['locked'] as bool? ?? false,
        hidden: json['hidden'] as bool? ?? false,
        shapeType: json['shapeType'] as String,
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        color: json['color'] as int,
        strokeWidth: (json['strokeWidth'] as num).toDouble(),
        isFilled: json['isFilled'] as bool? ?? false,
      );
}

class CanvasDocument {
  final int version;
  final BackgroundData background;
  final List<CanvasObject> objects;

  const CanvasDocument({
    this.version = 1,
    required this.background,
    required this.objects,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'background': background.toJson(),
        'objects': objects.map((o) => o.toJson()).toList(),
      };

  factory CanvasDocument.fromJson(Map<String, dynamic> json) {
    return CanvasDocument(
      version: json['version'] as int? ?? 1,
      background: BackgroundData.fromJson(json['background'] as Map<String, dynamic>),
      objects: (json['objects'] as List? ?? [])
          .map((o) => CanvasObject.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}
