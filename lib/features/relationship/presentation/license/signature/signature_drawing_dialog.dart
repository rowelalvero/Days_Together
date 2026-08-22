import 'package:flutter/material.dart';

import 'package:days_together/features/relationship/presentation/license/painters/signature_painter.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// A full-screen dialog for freehand-drawing a signature, used by the
/// license editor. Extracted out of relationship_license_screen.dart
/// (Migration Phase 8).
class SignatureDrawingDialog extends StatefulWidget {
  final List<List<Offset>> initialStrokes;

  final String title;

  final LoveStoryTheme theme;

  const SignatureDrawingDialog({
    super.key,

    required this.initialStrokes,

    required this.title,

    required this.theme,
  });

  @override
  State<SignatureDrawingDialog> createState() => _SignatureDrawingDialogState();
}

class _SignatureDrawingDialogState extends State<SignatureDrawingDialog> {
  late List<List<Offset>> _strokes;

  @override
  void initState() {
    super.initState();

    // Create deep copy

    _strokes = widget.initialStrokes
        .map((stroke) => List<Offset>.from(stroke))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.theme.isDark
          ? const Color(0xFF10122B)
          : const Color(0xFFFFF0F5),

      appBar: AppBar(
        title: Text(
          widget.title,

          style: AppTypography.heading(fontWeight: FontWeight.bold, color: widget.theme.textColor),
        ),

        backgroundColor: Colors.transparent,

        elevation: 0,

        leading: IconButton(
          icon: Icon(Icons.close, color: widget.theme.textColor),

          onPressed: () => Navigator.pop(context),
        ),

        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _strokes.clear();
              });
            },

            child: Text(
              'Clear',

              style: AppTypography.body(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),

          child: Column(
            children: [
              Text(
                'Draw your signature inside the box below',

                style: AppTypography.body(fontSize: 14, color: widget.theme.textColor.withValues(alpha: 0.6)),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: Container(
                  width: double.infinity,

                  decoration: BoxDecoration(
                    color: widget.theme.isDark
                        ? Colors.black26
                        : Colors.white24,

                    borderRadius: BorderRadius.circular(16),

                    border: Border.all(
                      color: widget.theme.accentColor.withValues(alpha: 0.3),

                      width: 2,
                    ),
                  ),

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),

                    child: GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _strokes.add([details.localPosition]);
                        });
                      },

                      onPanUpdate: (details) {
                        setState(() {
                          if (_strokes.isNotEmpty) {
                            _strokes.last.add(details.localPosition);
                          }
                        });
                      },

                      child: CustomPaint(
                        painter: SignaturePainter(
                          strokes: _strokes,

                          color: widget.theme.accentColor,

                          strokeWidth: 4.0,
                        ),

                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,

                height: 52,

                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, _strokes);
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.theme.accentColor,

                    foregroundColor: Colors.white,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),

                  child: Text(
                    'Save Signature',

                    style: AppTypography.body(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
