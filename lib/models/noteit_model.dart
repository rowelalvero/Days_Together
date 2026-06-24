import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum NoteitType { drawing, photo, text }

class NoteitItem {
  final String id;
  final NoteitType type;
  final String? content; // Text content for text notes, serialized strokes for drawings
  final String? imagePath; // Local file path for photos
  final String? imageUrl; // Remote Storage URL for photos
  final String sender; // 'you' or 'partner'
  final DateTime createdAt;
  final Color? backgroundColor;

  NoteitItem({
    String? id,
    required this.type,
    this.content,
    this.imagePath,
    this.imageUrl,
    required this.sender,
    DateTime? createdAt,
    this.backgroundColor,
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
      };

  factory NoteitItem.fromJson(Map<String, dynamic> json) {
    final typeIndex = json['type'] as int? ?? 0;
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
}

class ScaleDrawingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  ScaleDrawingPainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    bool hasPoints = false;

    for (final stroke in strokes) {
      for (final p in stroke) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
        hasPoints = true;
      }
    }

    if (!hasPoints) return;

    final w = maxX - minX;
    final h = maxY - minY;
    if (w == 0 || h == 0) return;

    const padding = 8.0; // Reduced padding for small preview widgets
    final targetW = size.width - 2 * padding;
    final targetH = size.height - 2 * padding;

    final scaleX = targetW / w;
    final scaleY = targetH / h;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final targetCenterX = size.width / 2;
    final targetCenterY = size.height / 2;
    final sourceCenterX = minX + w / 2;
    final sourceCenterY = minY + h / 2;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final firstPoint = stroke.first;
      final startX = targetCenterX + (firstPoint.dx - sourceCenterX) * scale;
      final startY = targetCenterY + (firstPoint.dy - sourceCenterY) * scale;

      final path = Path()..moveTo(startX, startY);
      for (int i = 1; i < stroke.length; i++) {
        final p = stroke[i];
        final px = targetCenterX + (p.dx - sourceCenterX) * scale;
        final py = targetCenterY + (p.dy - sourceCenterY) * scale;
        path.lineTo(px, py);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScaleDrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
