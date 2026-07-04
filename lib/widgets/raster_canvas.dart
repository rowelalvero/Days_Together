import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';

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
  late PainterController _controller;
  final int _canvasSize = 600;
  int _lastDrawableCount = 0;
  BackgroundDrawable? _lastBackground;
  bool _isProcessing = false;

  bool get canUndo => _controller.canUndo;
  bool get canRedo => _controller.canRedo;

  @override
  void initState() {
    super.initState();
    _initController();
    _loadFromBase64();
  }

  void _initController() {
    _controller = PainterController(
      settings: PainterSettings(
        freeStyle: FreeStyleSettings(
          color: widget.brushColor,
          strokeWidth: widget.strokeWidth,
          mode: _getFreeStyleMode(widget.activeTool),
        ),
      ),
    );
    _controller.addListener(_onControllerChanged);
  }

  FreeStyleMode _getFreeStyleMode(CanvasTool tool) {
    switch (tool) {
      case CanvasTool.pen:
      case CanvasTool.pencil:
      case CanvasTool.marker:
        return FreeStyleMode.draw;
      case CanvasTool.eraser:
        return FreeStyleMode.erase;
      case CanvasTool.bucket:
        return FreeStyleMode.none;
    }
  }

  Color _getBrushColorForTool(CanvasTool tool, Color baseColor) {
    switch (tool) {
      case CanvasTool.pencil:
        return baseColor.withValues(alpha: 0.7);
      case CanvasTool.marker:
        return baseColor.withValues(alpha: 0.35);
      default:
        return baseColor;
    }
  }

  double _getStrokeWidthForTool(CanvasTool tool, double baseWidth) {
    switch (tool) {
      case CanvasTool.pencil:
        return baseWidth * 0.7;
      case CanvasTool.marker:
        return baseWidth * 2.5;
      case CanvasTool.eraser:
        return baseWidth * 3.0;
      default:
        return baseWidth;
    }
  }

  @override
  void didUpdateWidget(RasterCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update settings dynamically on controller
    final color = _getBrushColorForTool(widget.activeTool, widget.brushColor);
    final width = _getStrokeWidthForTool(widget.activeTool, widget.strokeWidth);
    final mode = _getFreeStyleMode(widget.activeTool);

    _controller.settings = _controller.settings.copyWith(
      freeStyle: FreeStyleSettings(
        color: color,
        strokeWidth: width,
        mode: mode,
      ),
    );

    if (widget.initialBase64 != oldWidget.initialBase64) {
      _loadFromBase64();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_isProcessing) return;
    
    final drawablesChanged = _controller.drawables.length != _lastDrawableCount;
    final bgChanged = _controller.value.background != _lastBackground;
    
    if (drawablesChanged || bgChanged) {
      _lastDrawableCount = _controller.drawables.length;
      _lastBackground = _controller.value.background;
      
      widget.onUndoRedoStateChanged?.call(_controller.canUndo, _controller.canRedo);
      _notifyParent();
    }
  }

  Future<void> _notifyParent() async {
    if (_isProcessing) return;
    try {
      // Temporarily remove background to export ONLY the drawing layer
      final bg = _controller.value.background;
      _isProcessing = true;
      _controller.background = null;
      
      final image = await _controller.renderImage(Size(_canvasSize.toDouble(), _canvasSize.toDouble()));
      _controller.background = bg;
      _isProcessing = false;
      
      final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (pngData != null) {
        final base64String = base64Encode(pngData.buffer.asUint8List());
        widget.onDrawingLayerChanged(base64String);
      }
    } catch (e) {
      _isProcessing = false;
      debugPrint('RasterCanvas: Error rendering image: $e');
    }
  }

  Future<void> _loadFromBase64() async {
    if (widget.initialBase64 == null || widget.initialBase64!.isEmpty) {
      _controller.clearDrawables();
      return;
    }
    try {
      _isProcessing = true;
      final bytes = base64Decode(widget.initialBase64!);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (img) {
        completer.complete(img);
      });
      final img = await completer.future;
      
      final imageDrawable = ImageDrawable(
        image: img,
        position: Offset(_canvasSize / 2, _canvasSize / 2),
      );
      
      _controller.clearDrawables();
      _controller.addDrawables([imageDrawable]);
      _lastDrawableCount = _controller.drawables.length;
      _isProcessing = false;
    } catch (e) {
      _isProcessing = false;
      debugPrint('RasterCanvas: Error loading base64: $e');
    }
  }

  void undo() {
    _controller.undo();
    widget.onUndoRedoStateChanged?.call(_controller.canUndo, _controller.canRedo);
  }

  void redo() {
    _controller.redo();
    widget.onUndoRedoStateChanged?.call(_controller.canUndo, _controller.canRedo);
  }

  void clearAll() {
    _controller.clearDrawables();
    _controller.background = null;
    widget.onUndoRedoStateChanged?.call(_controller.canUndo, _controller.canRedo);
  }

  int _colorToRgba(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    final a = (color.a * 255.0).round().clamp(0, 255);
    return (a << 24) | (b << 16) | (g << 8) | r;
  }

  Future<void> _performFloodFill(Offset localPos) async {
    try {
      _isProcessing = true;
      // 1. Render current composition to get pixels
      final bg = _controller.value.background;
      _isProcessing = true;
      _controller.background = null;
      final image = await _controller.renderImage(Size(_canvasSize.toDouble(), _canvasSize.toDouble()));
      _controller.background = bg;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        _isProcessing = false;
        return;
      }
      final Uint32List pixels = byteData.buffer.asUint32List();

      if (!mounted) {
        _isProcessing = false;
        return;
      }
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final size = renderBox.size;
      final targetX = ((localPos.dx / size.width) * _canvasSize).round().clamp(0, _canvasSize - 1);
      final targetY = ((localPos.dy / size.height) * _canvasSize).round().clamp(0, _canvasSize - 1);
      final targetIdx = targetY * _canvasSize + targetX;

      final targetColor = pixels[targetIdx];
      final fillColor = _colorToRgba(widget.brushColor);

      if (targetColor == fillColor) {
        _isProcessing = false;
        return;
      }

      // Check if transparent
      if ((targetColor & 0xFF000000) == 0) {
        // Change canvas background color
        _controller.background = widget.brushColor.backgroundDrawable;
        widget.onCanvasBgColorChanged(widget.brushColor);
        _isProcessing = false;
        widget.onUndoRedoStateChanged?.call(_controller.canUndo, _controller.canRedo);
        return;
      }

      // Perform BFS Flood Fill on pixels
      final List<int> queue = [targetIdx];
      int head = 0;

      while (head < queue.length) {
        final idx = queue[head++];
        if (pixels[idx] == targetColor) {
          pixels[idx] = fillColor;
          
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
      final imageDrawable = ImageDrawable(
        image: finalImg,
        position: Offset(_canvasSize / 2, _canvasSize / 2),
      );

      _controller.clearDrawables();
      _controller.addDrawables([imageDrawable]);
      _lastDrawableCount = _controller.drawables.length;
      _isProcessing = false;

      widget.onUndoRedoStateChanged?.call(_controller.canUndo, _controller.canRedo);
      _notifyParent();
    } catch (e) {
      _isProcessing = false;
      debugPrint('RasterCanvas: Error performing flood fill: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final useBucket = widget.activeTool == CanvasTool.bucket;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: useBucket ? (details) => _performFloodFill(details.localPosition) : null,
      child: FlutterPainter(
        controller: _controller,
      ),
    );
  }
}
