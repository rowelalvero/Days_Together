import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'canvas_document.dart';

enum NoteitType { drawing, photo, text }
enum SyncStatus { sending, synced, failed }

class NoteitItem {
  final String id;
  final NoteitType type;
  final String? content; // Text content for text notes, serialized strokes for drawings
  final String? imagePath; // Local file path for photos
  final String? imageUrl; // Remote Storage URL for photos
  final String sender; // 'you' or 'partner'
  final DateTime createdAt;
  final Color? backgroundColor;
  final SyncStatus syncStatus;

  NoteitItem({
    String? id,
    required this.type,
    this.content,
    this.imagePath,
    this.imageUrl,
    required this.sender,
    DateTime? createdAt,
    this.backgroundColor,
    this.syncStatus = SyncStatus.synced,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  NoteitItem copyWith({
    String? id,
    NoteitType? type,
    String? content,
    String? imagePath,
    String? imageUrl,
    String? sender,
    DateTime? createdAt,
    Color? backgroundColor,
    SyncStatus? syncStatus,
  }) {
    return NoteitItem(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      sender: sender ?? this.sender,
      createdAt: createdAt ?? this.createdAt,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'content': content,
        'imagePath': imagePath,
        'imageUrl': imageUrl,
        'sender': sender,
        'createdAt': createdAt.toIso8601String(),
        'backgroundColor': backgroundColor?.toARGB32(),
        'syncStatus': syncStatus.index,
      };

  factory NoteitItem.fromJson(Map<String, dynamic> json) {
    final typeIndex = json['type'] as int? ?? 0;
    final syncIndex = json['syncStatus'] as int? ?? SyncStatus.synced.index;
    return NoteitItem(
      id: json['id'] as String?,
      type: (typeIndex >= 0 && typeIndex < NoteitType.values.length)
          ? NoteitType.values[typeIndex]
          : NoteitType.drawing,
      content: json['content'] as String?,
      imagePath: json['imagePath'] as String?,
      imageUrl: json['imageUrl'] as String?,
      sender: json['sender'] as String? ?? 'you',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      backgroundColor: json['backgroundColor'] != null
          ? Color(json['backgroundColor'] as int)
          : null,
      syncStatus: (syncIndex >= 0 && syncIndex < SyncStatus.values.length)
          ? SyncStatus.values[syncIndex]
          : SyncStatus.synced,
    );
  }

  factory NoteitItem.fromSupabase(Map<String, dynamic> data, String currentUserId) {
    // 1. Parse Type (Enum) - Handle String comparison
    final typeStr = (data['type'] ?? 'text').toString();
    final type = NoteitType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => NoteitType.text,
    );

    // 2. Parse Sender
    final senderId = (data['sender_id'] ?? '').toString();
    final sender = (senderId == currentUserId) ? 'you' : 'partner';

    // 3. Parse Color - Handle both int and String
    Color? bgColor;
    final colorData = data['background_color'];
    if (colorData != null) {
      if (colorData is int) {
        bgColor = Color(colorData);
      } else if (colorData is String) {
        final parsedInt = int.tryParse(colorData);
        if (parsedInt != null) bgColor = Color(parsedInt);
      }
    }

    // 4. Parse Date - Handle potential non-string or null
    DateTime createdAt;
    try {
      final dateStr = data['created_at'];
      createdAt = (dateStr != null) 
          ? DateTime.parse(dateStr.toString()).toLocal() 
          : DateTime.now();
    } catch (_) {
      createdAt = DateTime.now();
    }

    return NoteitItem(
      id: (data['id'] ?? '').toString(),
      type: type,
      content: data['content']?.toString(),
      imageUrl: data['image_url']?.toString(),
      sender: sender,
      createdAt: createdAt,
      backgroundColor: bgColor,
      syncStatus: SyncStatus.synced,
    );
  }

  static List<List<Offset>> deserializeStrokes(String? data) {
    if (data == null || data.isEmpty) return [];
    try {
      return data.split('|').map((strokeStr) {
        if (strokeStr.isEmpty) return <Offset>[];
        return strokeStr.split(';').map((pointStr) {
          final parts = pointStr.split(',');
          return Offset(double.parse(parts[0]), double.parse(parts[1]));
        }).toList();
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static List<ColorfulStroke> deserializeColorfulStrokes(String? data, Color defaultColor) {
    if (data == null || data.isEmpty) return [];
    try {
      final trimmed = data.trim();
      if (trimmed.startsWith('{')) {
        final doc = CanvasDocument.fromJson(jsonDecode(trimmed));
        final List<ColorfulStroke> list = [];
        for (final obj in doc.objects) {
          if (obj is StrokeObject && !obj.isEraser) {
            final points = obj.points.map((p) => Offset(p.x, p.y)).toList();
            list.add(ColorfulStroke(
              points: points,
              color: Color(obj.color),
              strokeWidth: obj.strokeWidth,
            ));
          }
        }
        return list;
      } else {
        final legacy = deserializeStrokes(data);
        return legacy.map((s) => ColorfulStroke(
          points: s,
          color: defaultColor,
          strokeWidth: 2.5,
        )).toList();
      }
    } catch (e) {
      debugPrint('Failed to deserialize colorful strokes: $e');
      return [];
    }
  }
}

class ColorfulStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  ColorfulStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

// ScaleDrawingPainter previously duplicated here; the canonical definition
// now lives in lib/shared/scale_drawing_painter.dart (a CustomPainter is a
// Flutter rendering type and does not belong in the model layer) -- see
// architecture Phase 0 (docs/architecture/migration-roadmap.md).

// CanvasPoint previously duplicated here; the canonical definition lives in
// canvas_document.dart (already imported above) -- see architecture Phase 0
// (docs/architecture/migration-roadmap.md).

class CanvasStroke {
  final List<CanvasPoint> points;
  final int color;
  final double strokeWidth;
  final String penType;
  CanvasStroke({required this.points, required this.color, required this.strokeWidth, required this.penType});
  Map<String, dynamic> toJson() => {'points': points.map((p) => p.toJson()).toList(), 'color': color, 'strokeWidth': strokeWidth, 'penType': penType};
  factory CanvasStroke.fromJson(Map<String, dynamic> json) => CanvasStroke(
        points: (json['points'] as List).map((p) => CanvasPoint.fromJson(p)).toList(),
        color: json['color'] as int,
        strokeWidth: (json['strokeWidth'] as num).toDouble(),
        penType: json['penType'] as String? ?? 'pen',
      );
}

class CanvasTextOverlay {
  final String id;
  final String text;
  final double x;
  final double y;
  final double scale;
  final double fontSize;
  final int color;
  final int backgroundColor;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String alignment;

  CanvasTextOverlay({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.scale,
    required this.fontSize,
    required this.color,
    required this.backgroundColor,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.alignment,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'x': x,
        'y': y,
        'scale': scale,
        'fontSize': fontSize,
        'color': color,
        'backgroundColor': backgroundColor,
        'isBold': isBold,
        'isItalic': isItalic,
        'isUnderline': isUnderline,
        'alignment': alignment,
      };

  factory CanvasTextOverlay.fromJson(Map<String, dynamic> json) => CanvasTextOverlay(
        id: json['id'] as String,
        text: json['text'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        scale: (json['scale'] as num? ?? 1.0).toDouble(),
        fontSize: (json['fontSize'] as num? ?? 20.0).toDouble(),
        color: json['color'] as int,
        backgroundColor: json['backgroundColor'] as int? ?? 0,
        isBold: json['isBold'] as bool? ?? false,
        isItalic: json['isItalic'] as bool? ?? false,
        isUnderline: json['isUnderline'] as bool? ?? false,
        alignment: json['alignment'] as String? ?? 'center',
      );
}

class CanvasData {
  final int version;
  final int backgroundColor;
  final String? backgroundImage;
  final String? drawingLayer;
  final List<CanvasTextOverlay> textOverlays;

  CanvasData({
    this.version = 1,
    required this.backgroundColor,
    this.backgroundImage,
    this.drawingLayer,
    required this.textOverlays,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'backgroundColor': backgroundColor,
        'backgroundImage': backgroundImage,
        'drawingLayer': drawingLayer,
        'textOverlays': textOverlays.map((o) => o.toJson()).toList(),
      };

  factory CanvasData.fromJson(Map<String, dynamic> json) => CanvasData(
        version: json['version'] as int? ?? 1,
        backgroundColor: json['backgroundColor'] as int,
        backgroundImage: json['backgroundImage'] as String?,
        drawingLayer: json['drawingLayer'] as String?,
        textOverlays: (json['textOverlays'] as List? ?? [])
            .map((o) => CanvasTextOverlay.fromJson(o))
            .toList(),
      );

  static bool isJson(String? data) {
    if (data == null) return false;
    return data.trim().startsWith('{') && data.trim().endsWith('}');
  }
}

