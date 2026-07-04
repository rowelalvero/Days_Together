import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';

class RasterCanvas extends StatefulWidget {
  final PainterController controller;
  final VoidCallback? onUpdate;

  const RasterCanvas({
    super.key,
    required this.controller,
    this.onUpdate,
  });

  @override
  State<RasterCanvas> createState() => RasterCanvasState();
}

class RasterCanvasState extends State<RasterCanvas> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleUpdate);
  }

  @override
  void didUpdateWidget(RasterCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleUpdate);
      widget.controller.addListener(_handleUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleUpdate);
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) {
      widget.onUpdate?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FlutterPainter(
        controller: widget.controller,
      ),
    );
  }
}
