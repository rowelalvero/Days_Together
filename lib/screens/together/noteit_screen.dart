import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/noteit_provider.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/services/permission_service.dart';
import 'package:days_together/services/noteit_sync_manager.dart';
import 'package:days_together/widgets/color_picker_dialog.dart';
import 'package:days_together/widgets/raster_canvas.dart';
import 'package:days_together/widgets/custom_backgrounds.dart';
import 'package:days_together/models/canvas_document.dart';
import 'package:days_together/utils/canvas_mapping.dart';

class NoteitScreen extends StatefulWidget {
  const NoteitScreen({super.key});

  @override
  State<NoteitScreen> createState() => _NoteitScreenState();
}

class _NoteitScreenState extends State<NoteitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  
  late PainterController _controller;
  
  // Active Modes: 'select', 'pen', 'pencil', 'marker', 'eraser', 'shapes'
  String _activeMode = 'pen';
  String _activeShape = 'rectangle'; // 'rectangle', 'oval', 'line', 'arrow'
  
  Color _brushColor = const Color(0xFFFF4D6D);
  double _strokeWidth = 4.0;
  
  // Rich Text Configuration State
  double _fontSize = 20.0;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  String _activeFontFamily = 'Spectral';
  final List<String> _fontFamilies = [
    'Spectral',
    'Cormorant Garamond',
    'Outfit',
    'Montserrat',
    'Playfair Display',
    'Pacifico',
    'Dancing Script',
    'Great Vibes',
    'Caveat',
    'Amatic SC',
  ];
  
  // Background configuration
  String _bgType = 'color'; // 'color', 'gradient', 'grid', 'dots', 'notebook'
  Color _bgColor = Colors.white;
  
  bool _isSaving = false;

  final List<Color> _paletteColors = [
    const Color(0xFFFF4D6D), // pink
    const Color(0xFFFF85A1), // light pink
    const Color(0xFFFFB3C1), // soft pink
    const Color(0xFF00B4D8), // cyan
    const Color(0xFF9D4EDD), // purple
    const Color(0xFFD4AF37), // gold
    Colors.white,
    Colors.black,
  ];

  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
    _initController();
    _loadDraft();
  }
  
  void _initController() {
    _controller = PainterController(
      settings: PainterSettings(
        freeStyle: const FreeStyleSettings(
          mode: FreeStyleMode.draw,
          color: Color(0xFFFF4D6D),
          strokeWidth: 4.0,
        ),
        scale: const ScaleSettings(
          enabled: false,
        ),
      ),
    );
    _controller.background = ColorBackgroundDrawable(color: _bgColor);
    _controller.addListener(_onControllerUpdated);
  }

  void _onControllerUpdated() {
    if (mounted) {
      setState(() {});
    }
    _saveDraft();
  }

  Future<void> _saveDraft() async {
    try {
      final doc = CanvasMapping.toDocument(_controller.drawables, _controller.value.background);
      final jsonStr = jsonEncode(doc.toJson());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('noteit_draft_canvas', jsonStr);
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('noteit_draft_canvas');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final doc = CanvasDocument.fromJson(jsonDecode(jsonStr));
        final drawables = await CanvasMapping.toDrawables(doc);
        
        setState(() {
          _controller.value = _controller.value.copyWith(
            background: CanvasMapping.toBackgroundDrawable(doc.background),
            drawables: drawables,
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    }
  }

  void _updateSettings() {
    FreeStyleMode mode = FreeStyleMode.none;
    Color color = _brushColor;
    double width = _strokeWidth;
    ShapeFactory? shapeFactory;

    switch (_activeMode) {
      case 'pen':
        mode = FreeStyleMode.draw;
        break;
      case 'pencil':
        mode = FreeStyleMode.draw;
        color = _brushColor.withValues(alpha: 0.7);
        width = _strokeWidth * 0.7;
        break;
      case 'marker':
        mode = FreeStyleMode.draw;
        color = _brushColor.withValues(alpha: 0.35);
        width = _strokeWidth * 2.5;
        break;
      case 'eraser':
        mode = FreeStyleMode.erase;
        width = _strokeWidth * 3.0;
        break;
      case 'shapes':
        mode = FreeStyleMode.none;
        if (_activeShape == 'rectangle') {
          shapeFactory = RectangleFactory();
        } else if (_activeShape == 'oval') {
          shapeFactory = OvalFactory();
        } else if (_activeShape == 'line') {
          shapeFactory = LineFactory();
        } else if (_activeShape == 'arrow') {
          shapeFactory = ArrowFactory();
        }
        break;
      case 'hand':
      case 'select':
      default:
        mode = FreeStyleMode.none;
        break;
    }

    _controller.settings = _controller.settings.copyWith(
      freeStyle: FreeStyleSettings(
        mode: mode,
        color: color,
        strokeWidth: width,
      ),
      shape: ShapeSettings(
        factory: shapeFactory,
        paint: Paint()
          ..color = _brushColor
          ..strokeWidth = _strokeWidth
          ..style = PaintingStyle.stroke,
        drawOnce: true,
      ),
    );
  }

  void _updateBackground() {
    switch (_bgType) {
      case 'gradient':
        _controller.background = const GradientBackgroundDrawable(
          colors: [Color(0xFFFF85A1), Color(0xFFD4AF37)],
        );
        break;
      case 'grid':
        _controller.background = GridBackgroundDrawable(
          backgroundColor: _bgColor,
          step: 25.0,
        );
        break;
      case 'dots':
        _controller.background = DotsBackgroundDrawable(
          backgroundColor: _bgColor,
          step: 25.0,
        );
        break;
      case 'notebook':
        _controller.background = NotebookBackgroundDrawable(
          backgroundColor: _bgColor,
          step: 30.0,
        );
        break;
      case 'color':
      default:
        _controller.background = ColorBackgroundDrawable(color: _bgColor);
        break;
    }
  }

  TextStyle _getTextStyle({
    required double fontSize,
    required Color color,
    required bool isBold,
    required bool isItalic,
    required bool isUnderline,
    required String fontFamily,
  }) {
    try {
      return GoogleFonts.getFont(
        fontFamily,
        fontSize: fontSize,
        color: color,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
      );
    } catch (_) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        color: color,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
      );
    }
  }

  void _addText() async {
    setState(() {
      _activeMode = 'text';
      _updateSettings();
    });

    final text = await _showTextInputDialog("");
    if (text != null && text.trim().isNotEmpty) {
      final renderBox = _controller.painterKey.currentContext?.findRenderObject() as RenderBox?;
      final center = renderBox == null
          ? const Offset(300, 300)
          : Offset(renderBox.size.width / 2, renderBox.size.height / 2);
          
      final textDrawable = TextDrawable(
        text: text,
        position: center,
        style: _getTextStyle(
          fontSize: _fontSize,
          color: _brushColor,
          isBold: _isBold,
          isItalic: _isItalic,
          isUnderline: _isUnderline,
          fontFamily: _activeFontFamily,
        ),
      );
      _controller.addDrawables([textDrawable]);
      _controller.selectObjectDrawable(textDrawable);
    }
  }

  Future<String?> _showTextInputDialog(String initialText) {
    final theme = context.read<ThemeProvider>().currentLoveTheme;
    final textController = TextEditingController(text: initialText);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: Text(
          initialText.isEmpty ? 'Add Text' : 'Edit Text',
          style: AppTypography.sectionHeader(color: theme.textColor, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: AppTypography.body(color: theme.textColor),
          decoration: InputDecoration(
            hintText: 'Type something...',
            hintStyle: TextStyle(color: theme.textColor.withValues(alpha: 0.5)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.2))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accentColor)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTypography.button(color: theme.textColor.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, textController.text),
            child: Text('Save', style: AppTypography.button(color: theme.accentColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _importImage(ImageSource source) async {
    final permissionService = PermissionService();
    final bool hasPermission;
    if (source == ImageSource.camera) {
      hasPermission = await permissionService.requestCameraPermission(context);
    } else {
      hasPermission = await permissionService.requestPhotosPermission(context);
    }
    if (!mounted || !hasPermission) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await File(picked.path).readAsBytes();
        final uiImg = await _decodeImageBytes(bytes);
        
        final renderBox = _controller.painterKey.currentContext?.findRenderObject() as RenderBox?;
        final center = renderBox == null
            ? const Offset(300, 300)
            : Offset(renderBox.size.width / 2, renderBox.size.height / 2);
            
        final imageDrawable = ImageDrawable(
          image: uiImg,
          position: center,
        );
        _controller.addDrawables([imageDrawable]);
      }
    } catch (e) {
      debugPrint('Error importing image: $e');
    }
  }

  Future<ui.Image> _decodeImageBytes(List<int> bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(Uint8List.fromList(bytes), (img) {
      completer.complete(img);
    });
    return completer.future;
  }

  void _clearCanvas(LoveStoryTheme theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: Text(
          'Clear Canvas?',
          style: AppTypography.sectionHeader(color: theme.textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to clear all doodles, shapes, text, and reset the canvas background?',
          style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTypography.button(color: theme.textColor.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _controller.clearDrawables();
                _bgColor = Colors.white;
                _bgType = 'color';
                _updateBackground();
              });
            },
            child: Text('Clear All', style: AppTypography.button(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _duplicateSelected(ObjectDrawable selected) {
    if (selected is TextDrawable) {
      final copy = TextDrawable(
        text: selected.text,
        position: selected.position + const Offset(30, 30),
        style: selected.style,
        rotation: selected.rotationAngle,
        scale: selected.scale,
        direction: selected.direction,
      );
      _controller.addDrawables([copy]);
      _controller.selectObjectDrawable(copy);
    } else if (selected is RectangleDrawable) {
      final copy = selected.copyWith(position: selected.position + const Offset(30, 30));
      _controller.addDrawables([copy]);
      _controller.selectObjectDrawable(copy);
    } else if (selected is OvalDrawable) {
      final copy = selected.copyWith(position: selected.position + const Offset(30, 30));
      _controller.addDrawables([copy]);
      _controller.selectObjectDrawable(copy);
    } else if (selected is LineDrawable) {
      final copy = selected.copyWith(position: selected.position + const Offset(30, 30));
      _controller.addDrawables([copy]);
      _controller.selectObjectDrawable(copy);
    } else if (selected is ArrowDrawable) {
      final copy = selected.copyWith(position: selected.position + const Offset(30, 30));
      _controller.addDrawables([copy]);
      _controller.selectObjectDrawable(copy);
    }
  }

  void _bringForward(Drawable drawable) {
    final list = List<Drawable>.from(_controller.value.drawables);
    final idx = list.indexOf(drawable);
    if (idx != -1 && idx < list.length - 1) {
      list.removeAt(idx);
      list.insert(idx + 1, drawable);
      _controller.value = _controller.value.copyWith(drawables: list);
    }
  }

  void _sendBackward(Drawable drawable) {
    final list = List<Drawable>.from(_controller.value.drawables);
    final idx = list.indexOf(drawable);
    if (idx > 0) {
      list.removeAt(idx);
      list.insert(idx - 1, drawable);
      _controller.value = _controller.value.copyWith(drawables: list);
    }
  }

  Future<void> _sendCanvas(NoteitProvider provider, LoveStoryTheme theme) async {
    if (_controller.drawables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add some drawings, shapes, or notes to the canvas! 🎨'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 1. Export entire canvas composition as flat PNG
      final image = await _controller.renderImage(const Size(1000, 1000));
      final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (pngData == null) throw Exception('Failed to render PNG data');
      
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/canvas_export_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngData.buffer.asUint8List());

      // 2. Serialize objects to JSON CanvasDocument
      final doc = CanvasMapping.toDocument(_controller.drawables, _controller.value.background);
      final jsonStr = jsonEncode(doc.toJson());

      // 3. Send via sync manager
      await provider.sendCanvas(jsonStr, file.path);

      // 4. Reset & Clear draft
      _controller.clearDrawables();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('noteit_draft_canvas');

      _tabController.animateTo(1); // Switch to history tab
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Canvas sent to partner! 🚀'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending canvas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.removeListener(_onControllerUpdated);
    _controller.dispose();
    
    // Clear draft on exit
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('noteit_draft_canvas');
    });
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final provider = context.watch<NoteitProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Infinite Canvas Doodles',
          style: AppTypography.cormorant(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: _currentTabIndex == 0
            ? [
                IconButton(
                  icon: Icon(Icons.undo_rounded, color: theme.textColor),
                  onPressed: _controller.canUndo ? () => _controller.undo() : null,
                  tooltip: 'Undo',
                ),
                IconButton(
                  icon: Icon(Icons.redo_rounded, color: theme.textColor),
                  onPressed: _controller.canRedo ? () => _controller.redo() : null,
                  tooltip: 'Redo',
                ),
                IconButton(
                  icon: Icon(Icons.delete_sweep_rounded, color: theme.textColor),
                  onPressed: () => _clearCanvas(theme),
                  tooltip: 'Clear Canvas',
                ),
                IconButton(
                  icon: Icon(Icons.palette_outlined, color: theme.textColor),
                  onPressed: () => _showBackgroundSettingsDialog(theme),
                  tooltip: 'Canvas Settings',
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.accentColor,
          labelColor: theme.textColor,
          unselectedLabelColor: theme.textColor.withValues(alpha: 0.5),
          tabs: const [
            Tab(text: '🎨 Workspace'),
            Tab(text: '📜 History'),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // Prevent conflict with panning
            children: [
              _buildCanvasWorkspace(theme, provider),
              _buildHistoryLog(theme, provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasWorkspace(LoveStoryTheme theme, NoteitProvider provider) {
    final selectedObj = _controller.value.selectedObjectDrawable;
    
    return Stack(
      children: [
        // The Infinite Canvas
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 120), // Leave space for properties & toolbar
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: RasterCanvas(
                      controller: _controller,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Floating Selected Object toolbar
        if (selectedObj != null)
          Positioned(
            top: 10,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: theme.backgroundColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(selectedObj.locked ? Icons.lock_rounded : Icons.lock_open_rounded, color: theme.textColor),
                    onPressed: () {
                      final updated = selectedObj.copyWith(locked: !selectedObj.locked);
                      _controller.replaceDrawable(selectedObj, updated);
                      _controller.selectObjectDrawable(updated);
                    },
                    tooltip: selectedObj.locked ? 'Unlock Object' : 'Lock Object',
                  ),
                  IconButton(
                    icon: Icon(Icons.flip_to_back_rounded, color: theme.textColor),
                    onPressed: () => _sendBackward(selectedObj),
                    tooltip: 'Send Backward',
                  ),
                  IconButton(
                    icon: Icon(Icons.flip_to_front_rounded, color: theme.textColor),
                    onPressed: () => _bringForward(selectedObj),
                    tooltip: 'Bring Forward',
                  ),
                  if (selectedObj is TextDrawable)
                    IconButton(
                      icon: Icon(Icons.edit_rounded, color: theme.textColor),
                      onPressed: () async {
                        final text = await _showTextInputDialog(selectedObj.text);
                        if (text != null && text.trim().isNotEmpty) {
                          final updated = selectedObj.copyWith(text: text);
                          _controller.replaceDrawable(selectedObj, updated);
                          _controller.selectObjectDrawable(updated);
                        }
                      },
                      tooltip: 'Edit Text Content',
                    ),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, color: theme.textColor),
                    onPressed: () => _duplicateSelected(selectedObj),
                    tooltip: 'Duplicate',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                    onPressed: () {
                      _controller.removeDrawable(selectedObj);
                      _controller.deselectObjectDrawable();
                    },
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ),
          ),

        // Floating Send Button
        Positioned(
          bottom: 110,
          right: 20,
          child: FloatingActionButton.extended(
            onPressed: _isSaving ? null : () => _sendCanvas(provider, theme),
            backgroundColor: theme.accentColor,
            elevation: 4,
            icon: _isSaving 
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white),
            label: Text(
              'Send',
              style: AppTypography.body(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // Bottom Configuration Sheets
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedObj != null)
                (selectedObj is TextDrawable
                    ? _buildTextPropertiesPanel(theme, selectedObj)
                    : _buildPropertiesPanel(theme))
              else if (_activeMode == 'text')
                _buildTextPropertiesPanel(theme, null)
              else if (_activeMode != 'select')
                _buildPropertiesPanel(theme),

              _buildBottomFloatingToolbar(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextPropertiesPanel(LoveStoryTheme theme, TextDrawable? selectedText) {
    final bool isBold = selectedText != null ? (selectedText.style.fontWeight == FontWeight.bold) : _isBold;
    final bool isItalic = selectedText != null ? (selectedText.style.fontStyle == FontStyle.italic) : _isItalic;
    final bool isUnderline = selectedText != null ? (selectedText.style.decoration == TextDecoration.underline) : _isUnderline;
    final Color activeColor = selectedText != null ? (selectedText.style.color ?? _brushColor) : _brushColor;

    String matchedFont = _activeFontFamily;
    if (selectedText != null && selectedText.style.fontFamily != null) {
      final family = selectedText.style.fontFamily!;
      for (final f in _fontFamilies) {
        if (family.toLowerCase().contains(f.toLowerCase())) {
          matchedFont = f;
          break;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Horizontal Font Family selector list
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _fontFamilies.length,
              itemBuilder: (ctx, idx) {
                final font = _fontFamilies[idx];
                final isSelected = matchedFont == font;
                
                TextStyle fontStyle = const TextStyle();
                try {
                  fontStyle = GoogleFonts.getFont(
                    font,
                    color: isSelected ? theme.accentColor : theme.textColor.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  );
                } catch (_) {
                  fontStyle = TextStyle(
                    fontFamily: font,
                    color: isSelected ? theme.accentColor : theme.textColor.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(font, style: fontStyle),
                    selected: isSelected,
                    selectedColor: theme.accentColor.withValues(alpha: 0.15),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: isSelected ? theme.accentColor : theme.textColor.withValues(alpha: 0.15),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          if (selectedText != null) {
                            final updated = selectedText.copyWith(
                              style: _getTextStyle(
                                fontSize: selectedText.style.fontSize ?? 20.0,
                                color: selectedText.style.color ?? _brushColor,
                                isBold: selectedText.style.fontWeight == FontWeight.bold,
                                isItalic: selectedText.style.fontStyle == FontStyle.italic,
                                isUnderline: selectedText.style.decoration == TextDecoration.underline,
                                fontFamily: font,
                              ),
                            );
                            _controller.replaceDrawable(selectedText, updated);
                            _controller.selectObjectDrawable(updated);
                          } else {
                            _activeFontFamily = font;
                          }
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Formatting controls & Color Picker Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Formatting toggles
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.format_bold, color: isBold ? theme.accentColor : theme.textColor.withValues(alpha: 0.6)),
                    onPressed: () {
                      setState(() {
                        if (selectedText != null) {
                          final updated = selectedText.copyWith(
                            style: selectedText.style.copyWith(
                              fontWeight: isBold ? FontWeight.normal : FontWeight.bold,
                            ),
                          );
                          _controller.replaceDrawable(selectedText, updated);
                          _controller.selectObjectDrawable(updated);
                        } else {
                          _isBold = !_isBold;
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.format_italic, color: isItalic ? theme.accentColor : theme.textColor.withValues(alpha: 0.6)),
                    onPressed: () {
                      setState(() {
                        if (selectedText != null) {
                          final updated = selectedText.copyWith(
                            style: selectedText.style.copyWith(
                              fontStyle: isItalic ? FontStyle.normal : FontStyle.italic,
                            ),
                          );
                          _controller.replaceDrawable(selectedText, updated);
                          _controller.selectObjectDrawable(updated);
                        } else {
                          _isItalic = !_isItalic;
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.format_underlined, color: isUnderline ? theme.accentColor : theme.textColor.withValues(alpha: 0.6)),
                    onPressed: () {
                      setState(() {
                        if (selectedText != null) {
                          final updated = selectedText.copyWith(
                            style: selectedText.style.copyWith(
                              decoration: isUnderline ? TextDecoration.none : TextDecoration.underline,
                            ),
                          );
                          _controller.replaceDrawable(selectedText, updated);
                          _controller.selectObjectDrawable(updated);
                        } else {
                          _isUnderline = !_isUnderline;
                        }
                      });
                    },
                  ),
                ],
              ),
              
              // Horizontal palette selection in remaining space
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _paletteColors.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == _paletteColors.length) {
                        return GestureDetector(
                          onTap: () async {
                            final pickedColor = await showDialog<Color>(
                              context: context,
                              builder: (ctx) => ColorPickerDialog(
                                initialColor: activeColor,
                                theme: theme,
                              ),
                            );
                            if (pickedColor != null) {
                              setState(() {
                                if (selectedText != null) {
                                  final updated = selectedText.copyWith(
                                    style: selectedText.style.copyWith(color: pickedColor),
                                  );
                                  _controller.replaceDrawable(selectedText, updated);
                                  _controller.selectObjectDrawable(updated);
                                } else {
                                  _brushColor = pickedColor;
                                }
                              });
                            }
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.textColor.withValues(alpha: 0.3), width: 1.5),
                              gradient: const SweepGradient(
                                colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.red],
                              ),
                            ),
                            child: Icon(Icons.add_rounded, color: theme.textColor, size: 18),
                          ),
                        );
                      }

                      final color = _paletteColors[i];
                      final isSelected = activeColor.toARGB32() == color.toARGB32();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selectedText != null) {
                                final updated = selectedText.copyWith(
                                  style: selectedText.style.copyWith(color: color),
                                );
                                _controller.replaceDrawable(selectedText, updated);
                                _controller.selectObjectDrawable(updated);
                              } else {
                                _brushColor = color;
                              }
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? theme.textColor : Colors.transparent,
                                width: 2.0,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesPanel(LoveStoryTheme theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Row with Stroke Width and Shape selection
          Row(
            children: [
              Text(
                'Width:',
                style: AppTypography.body(color: theme.textColor, fontSize: 13),
              ),
              Expanded(
                child: Slider(
                  value: _strokeWidth,
                  min: 1.0,
                  max: 20.0,
                  activeColor: theme.accentColor,
                  inactiveColor: theme.textColor.withValues(alpha: 0.1),
                  onChanged: (val) {
                    setState(() {
                      _strokeWidth = val;
                      _updateSettings();
                    });
                  },
                ),
              ),
              if (_activeMode == 'shapes') ...[
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _activeShape,
                  dropdownColor: theme.backgroundColor,
                  style: AppTypography.body(color: theme.textColor),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'rectangle', child: Text('Rectangle')),
                    DropdownMenuItem(value: 'oval', child: Text('Oval')),
                    DropdownMenuItem(value: 'line', child: Text('Line')),
                    DropdownMenuItem(value: 'arrow', child: Text('Arrow')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _activeShape = val;
                        _updateSettings();
                      });
                    }
                  },
                ),
              ],
            ],
          ),
          
          // Row with color palette picker
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _paletteColors.length + 1,
              itemBuilder: (ctx, i) {
                if (i == _paletteColors.length) {
                  return GestureDetector(
                    onTap: () async {
                      final pickedColor = await showDialog<Color>(
                        context: context,
                        builder: (ctx) => ColorPickerDialog(
                          initialColor: _brushColor,
                          theme: theme,
                        ),
                      );
                      if (pickedColor != null) {
                        setState(() {
                          _brushColor = pickedColor;
                          _updateSettings();
                        });
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.textColor.withValues(alpha: 0.3), width: 1.5),
                        gradient: const SweepGradient(
                          colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.red],
                        ),
                      ),
                      child: Icon(Icons.add_rounded, color: theme.textColor, size: 18),
                    ),
                  );
                }

                final color = _paletteColors[i];
                final isSelected = _brushColor.toARGB32() == color.toARGB32();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _brushColor = color;
                        _updateSettings();
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? theme.textColor : Colors.transparent,
                          width: 2.0,
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
    );
  }

  Widget _buildBottomFloatingToolbar(LoveStoryTheme theme) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mode Selectors
              _buildToolbarButton(Icons.near_me_rounded, 'select', 'Select Object'),
              _buildToolbarButton(Icons.edit_rounded, 'pen', 'Pen'),
              _buildToolbarButton(Icons.brush_rounded, 'pencil', 'Pencil'),
              _buildToolbarButton(Icons.border_color_rounded, 'marker', 'Marker'),
              _buildToolbarButton(Icons.cleaning_services_rounded, 'eraser', 'Eraser'),
              _buildToolbarButton(Icons.category_rounded, 'shapes', 'Shapes'),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 1,
                  height: 20,
                  color: theme.textColor.withValues(alpha: 0.15),
                ),
              ),

              // Content Actions
              IconButton(
                icon: const Icon(Icons.text_fields_rounded),
                onPressed: _addText,
                tooltip: 'Add Text',
                color: theme.textColor,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.photo_library_rounded),
                onPressed: () => _importImage(ImageSource.gallery),
                tooltip: 'Import Image',
                color: theme.textColor,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.photo_camera_rounded),
                onPressed: () => _importImage(ImageSource.camera),
                tooltip: 'Take Photo',
                color: theme.textColor,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarButton(IconData icon, String mode, String tooltip) {
    final isSelected = _activeMode == mode;
    final theme = context.read<ThemeProvider>().currentLoveTheme;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeMode = mode;
            _updateSettings();
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected ? theme.accentColor : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : theme.textColor.withValues(alpha: 0.7),
            size: 18,
          ),
        ),
      ),
    );
  }

  void _showBackgroundSettingsDialog(LoveStoryTheme theme) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.backgroundColor,
            title: Text(
              'Canvas Settings',
              style: AppTypography.sectionHeader(color: theme.textColor, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Background Template:', style: AppTypography.body(color: theme.textColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBgOptionButton(setDialogState, 'color', 'Solid color', Colors.white),
                    _buildBgOptionButton(setDialogState, 'grid', 'Grid Lines', Colors.white),
                    _buildBgOptionButton(setDialogState, 'dots', 'Dot Grid', Colors.white),
                    _buildBgOptionButton(setDialogState, 'notebook', 'Notebook', const Color(0xFFF9F9FB)),
                    _buildBgOptionButton(setDialogState, 'gradient', 'Gradient', Colors.white),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Solid Color Picker:', style: AppTypography.body(color: theme.textColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._paletteColors.map((color) {
                      final isSelectedColor = _bgType == 'color' && _bgColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            _bgColor = color;
                            _bgType = 'color';
                          });
                          setState(() {
                            _bgColor = color;
                            _bgType = 'color';
                            _updateBackground();
                          });
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelectedColor ? theme.textColor : Colors.grey.withValues(alpha: 0.3),
                              width: isSelectedColor ? 2.5 : 1.0,
                            ),
                          ),
                        ),
                      );
                    }),
                    GestureDetector(
                      onTap: () async {
                        final pickedColor = await showDialog<Color>(
                          context: context,
                          builder: (ctx2) => ColorPickerDialog(
                            initialColor: _bgColor,
                            theme: theme,
                          ),
                        );
                        if (pickedColor != null) {
                          setDialogState(() {
                            _bgColor = pickedColor;
                            _bgType = 'color';
                          });
                          setState(() {
                            _bgColor = pickedColor;
                            _bgType = 'color';
                            _updateBackground();
                          });
                        }
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.textColor.withValues(alpha: 0.3), width: 1.5),
                          gradient: const SweepGradient(
                            colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.red],
                          ),
                        ),
                        child: Icon(Icons.add_rounded, color: theme.textColor, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Done', style: AppTypography.button(color: theme.accentColor)),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildBgOptionButton(StateSetter setDialogState, String type, String label, Color previewColor) {
    final isSelected = _bgType == type;
    final theme = context.read<ThemeProvider>().currentLoveTheme;

    return OutlinedButton(
      onPressed: () {
        setDialogState(() {
          _bgType = type;
        });
        setState(() {
          _bgType = type;
          _updateBackground();
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? theme.accentColor : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : theme.textColor,
        side: BorderSide(color: isSelected ? theme.accentColor : theme.textColor.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  // 5. HISTORY LOG
  Widget _buildHistoryLog(LoveStoryTheme theme, NoteitProvider provider) {
    final list = provider.notes;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 48,
              color: theme.textColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No scrapbook canvases exchanged yet.',
              style: AppTypography.body(
                color: theme.textColor.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final item = list[idx];
        return GestureDetector(
          onTap: () => _showEnlargeNoteDialog(item, theme),
          onLongPress: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: theme.backgroundColor,
                title: Text(
                  'Delete Canvas?',
                  style: AppTypography.sectionHeader(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(
                  'Are you sure you want to delete this canvas from history?',
                  style: AppTypography.body(
                    color: theme.textColor.withValues(alpha: 0.8),
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  TextButton(
                    child: Text(
                      'Delete',
                      style: AppTypography.button(color: Colors.redAccent),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      provider.deleteNote(item.id);
                    },
                  ),
                ],
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: item.backgroundColor ?? theme.textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildWidgetContent(item),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.sender == 'you'
                            ? (item.syncStatus == SyncStatus.sending
                                ? '📤 Sending'
                                : item.syncStatus == SyncStatus.failed
                                    ? '⚠️ Failed'
                                    : '✅ Sent')
                            : 'Received',
                        style: AppTypography.bodyLarge(
                          fontSize: 8,
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (item.sender == 'you')
                    Positioned(
                      bottom: 6,
                      right: 8,
                      child: _buildSyncStatusBadge(item, theme),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSyncStatusBadge(NoteitItem item, LoveStoryTheme theme) {
    switch (item.syncStatus) {
      case SyncStatus.sending:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      case SyncStatus.failed:
        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: theme.backgroundColor,
                title: Text(
                  'Sync Failed',
                  style: AppTypography.sectionHeader(color: theme.textColor, fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'This canvas note couldn\'t be sent to your partner. Would you like to try sending it again?',
                  style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.8)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: AppTypography.button(color: theme.textColor.withValues(alpha: 0.6))),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      NoteitSyncManager.instance.retryTask(item.id);
                    },
                    child: Text('Retry Now', style: AppTypography.button(color: theme.accentColor)),
                  ),
                ],
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.refresh_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
        );
      case SyncStatus.synced:
        return const SizedBox.shrink();
    }
  }

  void _showEnlargeNoteDialog(NoteitItem item, LoveStoryTheme theme) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: item.backgroundColor ?? Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.textColor.withValues(alpha: 0.2), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: _buildWidgetContent(item),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                item.sender == 'you'
                    ? (item.syncStatus == SyncStatus.sending
                        ? 'Sending Canvas...'
                        : item.syncStatus == SyncStatus.failed
                            ? 'Failed to Send'
                            : 'Sent by You')
                    : 'Received from Partner',
                style: AppTypography.bodyLarge(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWidgetContent(NoteitItem item) {
    // If the canvas holds a flat rendered composition image, draw it directly!
    if (item.imagePath != null && File(item.imagePath!).existsSync()) {
      return Image.file(
        File(item.imagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return Image.network(
        item.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      );
    }

    // Fallback: Legacy drawings
    if (item.type == NoteitType.drawing) {
      return CustomPaint(
        painter: ScaleDrawingPainter(
          strokes: NoteitItem.deserializeStrokes(item.content),
          color: Colors.white,
          strokeWidth: 3.5,
        ),
      );
    } else if (item.type == NoteitType.text) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Text(
          item.content ?? '',
          textAlign: TextAlign.center,
          style: AppTypography.lora(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: Colors.white,
            height: 1.4,
          ),
        ),
      );
    }
    return Container(color: Colors.grey);
  }
}
