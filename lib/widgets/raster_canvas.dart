import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum CanvasTool { pen, pencil, marker, eraser, bucket }

class RasterCanvas extends StatefulWidget {
  final Color brushColor;
  final double strokeWidth;
  final CanvasTool activeTool;
  final String? initialBase64;
  final Function(String base64) onDrawingLayerChanged;
  final Function(Color color) onCanvasBgColorChanged;
  final Function(bool canUndo, bool canRedo)? onUndoRedoStateChanged;

  const RasterCanvas({
    super.key,
    required this.brushColor,
    required this.strokeWidth,
    required this.activeTool,
    this.initialBase64,
    required this.onDrawingLayerChanged,
    required this.onCanvasBgColorChanged,
    this.onUndoRedoStateChanged,
  });

  @override
  State<RasterCanvas> createState() => RasterCanvasState();
}

class RasterCanvasState extends State<RasterCanvas> {
  ui.Image? _drawingImage;
  bool _isDrawing = false;
  Offset? _lastPoint;
  final int _canvasSize = 600;

  final List<ui.Image> _undoStack = [];
  final List<ui.Image> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void _saveToUndoStack() {
    if (_drawingImage == null) return;
    _undoStack.add(_drawingImage!);
    _clearRedoStack();
    _notifyUndoRedoState();
  }

  void _clearRedoStack() {
    for (final img in _redoStack) {
      img.dispose();
    }
    _redoStack.clear();
  }

  void _notifyUndoRedoState() {
    widget.onUndoRedoStateChanged?.call(_undoStack.isNotEmpty, _redoStack.isNotEmpty);
  }

  void undo() {
    if (_undoStack.isEmpty || _drawingImage == null) return;
    final previousState = _undoStack.removeLast();
    _redoStack.add(_drawingImage!);
    setState(() {
      _drawingImage = previousState;
    });
    _notifyParent();
    _notifyUndoRedoState();
  }

  void redo() {
    if (_redoStack.isEmpty || _drawingImage == null) return;
    final nextState = _redoStack.removeLast();
    _undoStack.add(_drawingImage!);
    setState(() {
      _drawingImage = nextState;
    });
    _notifyParent();
    _notifyUndoRedoState();
  }

  @override
  void dispose() {
    for (final img in _undoStack) {
      img.dispose();
    }
    for (final img in _redoStack) {
      img.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initCanvas();
  }

  @override
  void didUpdateWidget(RasterCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialBase64 != oldWidget.initialBase64) {
      _loadFromBase64();
    }
  }

  Future<void> _initCanvas() async {
    if (widget.initialBase64 != null && widget.initialBase64!.isNotEmpty) {
      await _loadFromBase64();
    } else {
      await _clearCanvas();
    }
  }

  Future<void> _clearCanvas() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder); // Create canvas to bind to recorder
    
    // Draw nothing, keep transparent
    final picture = recorder.endRecording();
    final img = await picture.toImage(_canvasSize, _canvasSize);
    
    if (mounted) {
      setState(() {
        _drawingImage = img;
      });
      _notifyParent();
    }
  }

  Future<void> _loadFromBase64() async {
    if (widget.initialBase64 == null || widget.initialBase64!.isEmpty) {
      await _clearCanvas();
      return;
    }
    try {
      final bytes = base64Decode(widget.initialBase64!);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (img) {
        completer.complete(img);
      });
      final img = await completer.future;
      if (mounted) {
        setState(() {
          _drawingImage = img;
        });
      }
    } catch (e) {
      debugPrint('RasterCanvas: Error loading base64: $e');
      await _clearCanvas();
    }
  }

  void clearAll() {
    _saveToUndoStack();
    _clearCanvas();
  }

  // Helper: Convert Flutter Color to RGBA 32-bit int (little-endian byte order: R, G, B, A)
  int _colorToRgba(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    final a = (color.a * 255.0).round().clamp(0, 255);
    return (a << 24) | (b << 16) | (g << 8) | r;
  }

  // Flood fill BFS algorithm in Dart
  Future<void> _performFloodFill(Offset localPos) async {
    if (_drawingImage == null) return;
    _saveToUndoStack();

    // Map gesture offset to 600x600 canvas coordinate
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final int startX = ((localPos.dx / size.width) * _canvasSize).clamp(0, _canvasSize - 1).toInt();
    final int startY = ((localPos.dy / size.height) * _canvasSize).clamp(0, _canvasSize - 1).toInt();

    final byteData = await _drawingImage!.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;

    final Uint32List pixels = byteData.buffer.asUint32List();
    final int targetIndex = startY * _canvasSize + startX;
    final int targetColor = pixels[targetIndex];
    final int replacementColor = _colorToRgba(widget.brushColor);

    // If target color is transparent (Alpha channel is 0), update canvas background color instead
    if ((targetColor & 0xFF000000) == 0) {
      widget.onCanvasBgColorChanged(widget.brushColor);
      return;
    }

    if (targetColor == replacementColor) return;

    // Run queue-based flood fill
    final queue = <int>[];
    queue.add(targetIndex);
    
    while (queue.isNotEmpty) {
      final idx = queue.removeAt(0);
      if (pixels[idx] == targetColor) {
        pixels[idx] = replacementColor;
        
        final x = idx % _canvasSize;
        final y = idx ~/ _canvasSize;
        
        if (x > 0 && pixels[idx - 1] == targetColor) queue.add(idx - 1);
        if (x < _canvasSize - 1 && pixels[idx + 1] == targetColor) queue.add(idx + 1);
        if (y > 0 && pixels[idx - _canvasSize] == targetColor) queue.add(idx - _canvasSize);
        if (y < _canvasSize - 1 && pixels[idx + _canvasSize] == targetColor) queue.add(idx + _canvasSize);
      }
    }

    // Convert pixel buffer back to ui.Image
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      byteData.buffer.asUint8List(),
      _canvasSize,
      _canvasSize,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );

    final finalImg = await completer.future;
    if (mounted) {
      setState(() {
        _drawingImage = finalImg;
      });
      _notifyParent();
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (widget.activeTool == CanvasTool.bucket) {
      _performFloodFill(details.localPosition);
      return;
    }
    _saveToUndoStack();
    setState(() {
      _isDrawing = true;
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final size = renderBox.size;
      _lastPoint = Offset(
        (details.localPosition.dx / size.width) * _canvasSize,
        (details.localPosition.dy / size.height) * _canvasSize,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDrawing || _lastPoint == null || _drawingImage == null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final currentPoint = Offset(
      (details.localPosition.dx / size.width) * _canvasSize,
      (details.localPosition.dy / size.height) * _canvasSize,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1. Draw existing image first
    canvas.drawImage(_drawingImage!, Offset.zero, Paint());

    // 2. Configure pen paint based on active tool
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = widget.strokeWidth
      ..style = PaintingStyle.stroke;

    switch (widget.activeTool) {
      case CanvasTool.pen:
        paint.color = widget.brushColor;
        break;
      case CanvasTool.pencil:
        paint.color = widget.brushColor.withValues(alpha: 0.7);
        paint.strokeWidth = widget.strokeWidth * 0.7;
        break;
      case CanvasTool.marker:
        paint.color = widget.brushColor.withValues(alpha: 0.35);
        paint.strokeWidth = widget.strokeWidth * 2.5;
        break;
      case CanvasTool.eraser:
        paint.color = Colors.black; // Color doesn't matter for clear blendmode
        paint.blendMode = ui.BlendMode.clear;
        paint.strokeWidth = widget.strokeWidth * 3;
        break;
      default:
        break;
    }

    // 3. Draw the line segment
    canvas.drawLine(_lastPoint!, currentPoint, paint);

    final picture = recorder.endRecording();
    picture.toImage(_canvasSize, _canvasSize).then((img) {
      if (mounted) {
        setState(() {
          _drawingImage = img;
          _lastPoint = currentPoint;
        });
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDrawing) return;
    setState(() {
      _isDrawing = false;
      _lastPoint = null;
    });
    _notifyParent();
  }

  Future<void> _notifyParent() async {
    if (_drawingImage == null) return;
    final pngData = await _drawingImage!.toByteData(format: ui.ImageByteFormat.png);
    if (pngData != null) {
      final base64String = base64Encode(pngData.buffer.asUint8List());
      widget.onDrawingLayerChanged(base64String);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: CustomPaint(
        painter: _DrawingPainter(image: _drawingImage),
        size: Size.infinite,
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final ui.Image? image;

  _DrawingPainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;
    
    // Draw the 600x600 image scaled to fit the custom paint size
    final src = Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image!, src, dst, Paint());
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
