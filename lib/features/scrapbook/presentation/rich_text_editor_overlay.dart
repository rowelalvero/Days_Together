import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/features/scrapbook/presentation/color_picker_dialog.dart';
import 'package:uuid/uuid.dart';

enum TextBgStyle { plain, solid, translucent }

class RichTextEditorOverlay extends StatefulWidget {
  final CanvasTextOverlay? initialOverlay;
  final LoveStoryTheme theme;

  const RichTextEditorOverlay({
    super.key,
    this.initialOverlay,
    required this.theme,
  });

  @override
  State<RichTextEditorOverlay> createState() => _RichTextEditorOverlayState();
}

class _RichTextEditorOverlayState extends State<RichTextEditorOverlay> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Styling properties
  Color _color = Colors.white;
  Color _bgColor = Colors.transparent;
  TextBgStyle _bgStyle = TextBgStyle.plain;
  double _fontSize = 20.0;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  TextAlign _alignment = TextAlign.center;

  final List<Color> _quickColors = [
    Colors.white,
    const Color(0xFFFF4D6D), // pink
    const Color(0xFFFF85A1), // light pink
    const Color(0xFF00B4D8), // cyan
    const Color(0xFF9D4EDD), // purple
    const Color(0xFFD4AF37), // gold
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialOverlay != null) {
      final o = widget.initialOverlay!;
      _controller.text = o.text;
      _color = Color(o.color);
      _bgColor = Color(o.backgroundColor);
      _isBold = o.isBold;
      _isItalic = o.isItalic;
      _isUnderline = o.isUnderline;
      _fontSize = o.fontSize;
      
      if (o.backgroundColor == 0) {
        _bgStyle = TextBgStyle.plain;
      } else if (Color(o.backgroundColor).a < 0.9) {
        _bgStyle = TextBgStyle.translucent;
      } else {
        _bgStyle = TextBgStyle.solid;
      }
      
      _alignment = o.alignment == 'left'
          ? TextAlign.left
          : o.alignment == 'right'
              ? TextAlign.right
              : TextAlign.center;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _cycleBgStyle() {
    setState(() {
      switch (_bgStyle) {
        case TextBgStyle.plain:
          _bgStyle = TextBgStyle.solid;
          _bgColor = _color == Colors.white ? const Color(0xFFFF4D6D) : _color;
          break;
        case TextBgStyle.solid:
          _bgStyle = TextBgStyle.translucent;
          _bgColor = Colors.black.withValues(alpha: 0.5);
          break;
        case TextBgStyle.translucent:
          _bgStyle = TextBgStyle.plain;
          _bgColor = Colors.transparent;
          break;
      }
    });
  }

  Future<void> _openCustomColorPicker() async {
    final pickedColor = await showDialog<Color>(
      context: context,
      builder: (ctx) => ColorPickerDialog(
        initialColor: _color,
        theme: widget.theme,
      ),
    );
    if (pickedColor != null) {
      setState(() {
        _color = pickedColor;
        if (_bgStyle == TextBgStyle.solid) {
          _bgColor = pickedColor;
        }
      });
    }
  }

  void _saveAndClose() {
    if (_controller.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }

    final id = widget.initialOverlay?.id ?? const Uuid().v4();
    final String alignmentStr = _alignment == TextAlign.left
        ? 'left'
        : _alignment == TextAlign.right
            ? 'right'
            : 'center';

    final textValColor = (_bgStyle == TextBgStyle.solid && _bgColor.computeLuminance() > 0.5) 
        ? Colors.black 
        : (_bgStyle == TextBgStyle.solid ? Colors.white : _color);

    final finalOverlay = CanvasTextOverlay(
      id: id,
      text: _controller.text,
      x: widget.initialOverlay?.x ?? 100.0,
      y: widget.initialOverlay?.y ?? 200.0,
      scale: widget.initialOverlay?.scale ?? 1.0,
      fontSize: _fontSize,
      color: textValColor.toARGB32(),
      backgroundColor: _bgStyle == TextBgStyle.plain ? 0 : _bgColor.toARGB32(),
      isBold: _isBold,
      isItalic: _isItalic,
      isUnderline: _isUnderline,
      alignment: alignmentStr,
    );

    Navigator.pop(context, finalOverlay);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTypography.lora(
      fontSize: _fontSize,
      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
      color: (_bgStyle == TextBgStyle.solid && _bgColor.computeLuminance() > 0.5) ? Colors.black : (_bgStyle == TextBgStyle.solid ? Colors.white : _color),
    ).copyWith(
      decoration: _isUnderline ? TextDecoration.underline : TextDecoration.none,
    );

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      body: SafeArea(
        child: Stack(
          children: [
            // Backdrop blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.transparent),
              ),
            ),

            // Top Control Bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  
                  // Text Bg Style Cycle Button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _bgStyle == TextBgStyle.plain ? Colors.white24 : _bgColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        'A',
                        style: TextStyle(
                          color: _bgStyle == TextBgStyle.solid && _bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    onPressed: _cycleBgStyle,
                    tooltip: 'Toggle background style',
                  ),
                  
                  // Alignment Toggle
                  IconButton(
                    icon: Icon(
                      _alignment == TextAlign.left
                          ? Icons.format_align_left_rounded
                          : _alignment == TextAlign.right
                              ? Icons.format_align_right_rounded
                              : Icons.format_align_center_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_alignment == TextAlign.center) {
                          _alignment = TextAlign.left;
                        } else if (_alignment == TextAlign.left) {
                          _alignment = TextAlign.right;
                        } else {
                          _alignment = TextAlign.center;
                        }
                      });
                    },
                  ),
                  
                  // Done Button
                  TextButton(
                    onPressed: _saveAndClose,
                    child: const Text(
                      'Done',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),

            // Text Input Box (Center)
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _bgStyle == TextBgStyle.plain ? Colors.transparent : _bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IntrinsicWidth(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              maxLines: null,
                              textAlign: _alignment,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: textStyle,
                              decoration: const InputDecoration(
                                hintText: 'Type message...',
                                hintStyle: TextStyle(color: Colors.white30),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom controls: Text Formatting & Color selection
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Formatting bar (Bold, Italic, Underline)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFormatButton(
                        icon: Icons.format_bold_rounded,
                        isActive: _isBold,
                        onPressed: () => setState(() => _isBold = !_isBold),
                      ),
                      const SizedBox(width: 12),
                      _buildFormatButton(
                        icon: Icons.format_italic_rounded,
                        isActive: _isItalic,
                        onPressed: () => setState(() => _isItalic = !_isItalic),
                      ),
                      const SizedBox(width: 12),
                      _buildFormatButton(
                        icon: Icons.format_underlined_rounded,
                        isActive: _isUnderline,
                        onPressed: () => setState(() => _isUnderline = !_isUnderline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Font Size Slider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Row(
                      children: [
                        const Icon(Icons.format_size_rounded, color: Colors.white70, size: 16),
                        Expanded(
                          child: Slider(
                            value: _fontSize,
                            min: 12.0,
                            max: 48.0,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white24,
                            onChanged: (val) {
                              setState(() {
                                _fontSize = val;
                              });
                            },
                          ),
                        ),
                        Text(
                          _fontSize.toInt().toString(),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Horizontal Color List
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _quickColors.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == _quickColors.length) {
                          // Custom color picker button
                          return GestureDetector(
                            onTap: _openCustomColorPicker,
                            child: Container(
                              width: 34,
                              height: 34,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                                gradient: const SweepGradient(
                                  colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.red],
                                ),
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                            ),
                          );
                        }

                        final color = _quickColors[i];
                        final isSelected = _color.toARGB32() == color.toARGB32();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _color = color;
                                if (_bgStyle == TextBgStyle.solid) {
                                  _bgColor = color;
                                }
                              });
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white10,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}
