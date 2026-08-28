import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/features/scrapbook/noteit_state.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/shared/scale_drawing_painter.dart';
import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/services/permission_service.dart';
import 'package:days_together/services/noteit_sync_manager.dart';
import 'package:days_together/features/scrapbook/presentation/color_picker_dialog.dart';
import 'package:days_together/features/scrapbook/presentation/raster_canvas.dart';
import 'package:days_together/features/scrapbook/presentation/custom_backgrounds.dart';
import 'package:days_together/utils/canvas_mapping.dart';
import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/shared/storage_image.dart';
import 'package:days_together/features/scrapbook/data/noteit_draft_store.dart';
import 'package:days_together/features/scrapbook/domain/scrapbook_share_use_case.dart';

class NoteitScreen extends ConsumerStatefulWidget {
  const NoteitScreen({super.key});

  @override
  ConsumerState<NoteitScreen> createState() => _NoteitScreenState();
}

class _NoteitScreenState extends ConsumerState<NoteitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  late PainterController _controller;

  // Active Modes: 'select', 'pen', 'pencil', 'marker', 'eraser', 'shapes'
  String _activeMode = 'pen';
  bool _isPropertiesPanelExpanded = true;
  ObjectDrawable? _lastSelectedObj;
  String _activeShape = 'rectangle'; // 'rectangle', 'oval', 'line', 'arrow'

  Color _brushColor = const Color(0xFFFF4D6D);
  double _strokeWidth = 4.0;

  // Rich Text Configuration State
  double _fontSize = 20.0;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  TextAlign _textAlign = TextAlign.center;
  Color _highlightColor = Colors.transparent;
  final List<Color> _highlightColors = [
    Colors.transparent,
    const Color(0xFFFFF2B2),
    const Color(0xFFC7F9CC),
    const Color(0xFFBEE9E8),
    const Color(0xFFFFD6E0),
    const Color(0xFFE8DBFC),
    const Color(0xFFFFE5D9),
  ];
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

  final NoteitDraftStore _draftStore = const NoteitDraftStore();

  final List<Color> _paletteColors = [
    Colors.black,
    const Color(0xFFFF4D6D), // pink
    const Color(0xFFFF85A1), // light pink
    const Color(0xFFFFB3C1), // soft pink
    const Color(0xFF00B4D8), // cyan
    const Color(0xFF9D4EDD), // purple
    const Color(0xFFD4AF37), // gold
    Colors.white,
  ];

  int _currentTabIndex = 0;

  // Inline text editing state
  bool _isInlineEditing = false;
  late TextEditingController _inlineTextController;
  late FocusNode _inlineTextFocusNode;
  CustomTextDrawable? _editingTextDrawable;
  bool _isEditingExistingText = false;

  @override
  void initState() {
    super.initState();
    _inlineTextController = TextEditingController();
    _inlineTextFocusNode = FocusNode();
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
        scale: const ScaleSettings(enabled: false),
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
    final doc = CanvasMapping.toDocument(
      _controller.drawables,
      _controller.value.background,
    );
    await _draftStore.save(doc);
  }

  Future<void> _loadDraft() async {
    final doc = await _draftStore.load();
    if (doc == null) return;

    final drawables = await CanvasMapping.toDrawables(doc);
    setState(() {
      _controller.value = _controller.value.copyWith(
        background: CanvasMapping.toBackgroundDrawable(doc.background),
        drawables: drawables,
      );
    });
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
    required Color highlightColor,
  }) {
    final bg = highlightColor != Colors.transparent ? highlightColor : null;
    try {
      return GoogleFonts.getFont(
        fontFamily,
        fontSize: fontSize,
        color: color,
        backgroundColor: bg,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: isUnderline
            ? TextDecoration.underline
            : TextDecoration.none,
      );
    } catch (_) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        color: color,
        backgroundColor: bg,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: isUnderline
            ? TextDecoration.underline
            : TextDecoration.none,
      );
    }
  }

  void _startInlineEditing({CustomTextDrawable? existingDrawable}) {
    final renderBox =
        _controller.painterKey.currentContext?.findRenderObject() as RenderBox?;
    final canvasWidth = renderBox?.size.width ?? 600.0;
    final canvasHeight = renderBox?.size.height ?? 600.0;
    final centerY = canvasHeight / 2;

    setState(() {
      _isInlineEditing = true;
      _activeMode = 'text';
      _isPropertiesPanelExpanded = true;
      _updateSettings();

      if (existingDrawable != null) {
        _editingTextDrawable = existingDrawable;
        _isEditingExistingText = true;
        _inlineTextController.text = existingDrawable.text;

        // Load the styles from the existing drawable
        _fontSize = existingDrawable.style.fontSize ?? 20.0;
        _brushColor = existingDrawable.style.color ?? const Color(0xFFFF4D6D);
        _isBold = existingDrawable.style.fontWeight == FontWeight.bold;
        _isItalic = existingDrawable.style.fontStyle == FontStyle.italic;
        _isUnderline =
            existingDrawable.style.decoration == TextDecoration.underline;
        _textAlign = existingDrawable.textAlign;
        _highlightColor =
            existingDrawable.style.backgroundColor ?? Colors.transparent;
        _activeFontFamily = existingDrawable.style.fontFamily ?? 'Spectral';

        // Hide original on canvas
        final hiddenDrawable = existingDrawable.copyWith(hidden: true);
        _controller.replaceDrawable(existingDrawable, hiddenDrawable);
        _editingTextDrawable = hiddenDrawable;

        // Deselect so the handles disappear
        _controller.deselectObjectDrawable();
      } else {
        _editingTextDrawable = null;
        _isEditingExistingText = false;
        _inlineTextController.clear();

        // Create a temporary hidden text layer
        final tempDrawable = CustomTextDrawable(
          text: '',
          position: Offset(canvasWidth / 2, centerY),
          style: _getTextStyle(
            fontSize: _fontSize,
            color: _brushColor,
            isBold: _isBold,
            isItalic: _isItalic,
            isUnderline: _isUnderline,
            fontFamily: _activeFontFamily,
            highlightColor: _highlightColor,
          ),
          textAlign: _textAlign,
          hidden: true,
        );
        _controller.addDrawables([tempDrawable]);
        _editingTextDrawable = tempDrawable;
      }
    });

    _inlineTextFocusNode.requestFocus();
  }

  void _finishInlineEditing({bool cancel = false}) {
    if (!_isInlineEditing) return;

    final text = _inlineTextController.text;
    final drawable = _editingTextDrawable;

    setState(() {
      _isInlineEditing = false;
    });

    if (cancel || text.trim().isEmpty) {
      if (drawable != null) {
        if (_isEditingExistingText) {
          // Restore original
          final restored = drawable.copyWith(hidden: false);
          _controller.replaceDrawable(drawable, restored);
          _controller.selectObjectDrawable(restored);
        } else {
          // Remove the temporary drawable
          _controller.removeDrawable(drawable);
        }
      }
    } else {
      if (drawable != null) {
        final renderBox =
            _controller.painterKey.currentContext?.findRenderObject()
                as RenderBox?;
        final canvasWidth = renderBox?.size.width ?? 600.0;

        final tempDrawable = CustomTextDrawable(
          text: text,
          position: drawable.position,
          style: _getTextStyle(
            fontSize: _fontSize,
            color: _brushColor,
            isBold: _isBold,
            isItalic: _isItalic,
            isUnderline: _isUnderline,
            fontFamily: _activeFontFamily,
            highlightColor: _highlightColor,
          ),
          textAlign: _textAlign,
          hidden: false,
        );

        final textWidth = tempDrawable.getSize().width * tempDrawable.scale;
        double newX = tempDrawable.position.dx;
        const double margin = 20.0;

        if (!_isEditingExistingText) {
          newX = canvasWidth / 2;
          if (_textAlign == TextAlign.left) {
            newX = (textWidth / 2) + margin;
          } else if (_textAlign == TextAlign.right) {
            newX = canvasWidth - (textWidth / 2) - margin;
          }
        }

        final finalDrawable = tempDrawable.copyWith(
          position: Offset(newX, drawable.position.dy),
        );

        _controller.replaceDrawable(drawable, finalDrawable);
        _controller.selectObjectDrawable(finalDrawable);
      }
    }

    _editingTextDrawable = null;
    _isEditingExistingText = false;
    _inlineTextController.clear();
    _inlineTextFocusNode.unfocus();
  }

  void _addText() {
    _startInlineEditing();
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

        final renderBox =
            _controller.painterKey.currentContext?.findRenderObject()
                as RenderBox?;
        final center = renderBox == null
            ? const Offset(300, 300)
            : Offset(renderBox.size.width / 2, renderBox.size.height / 2);

        final imageDrawable = ImageDrawable(image: uiImg, position: center);
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
          style: AppTypography.heading(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to clear all doodles, shapes, text, and reset the canvas background?',
          style: AppTypography.body(
            color: theme.textColor.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTypography.button(
                color: theme.textColor.withValues(alpha: 0.6),
              ),
            ),
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
            child: Text(
              'Clear All',
              style: AppTypography.button(color: Colors.redAccent),
            ),
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
      final copy = selected.copyWith(
        position: selected.position + const Offset(30, 30),
      );
      _controller.addDrawables([copy]);
      _controller.selectObjectDrawable(copy);
    } else if (selected is OvalDrawable) {
      final copy = selected.copyWith(
        position: selected.position + const Offset(30, 30),
      );
      _controller.addDrawables([copy]);
      _controller.selectObjectDrawable(copy);
    } else if (selected is LineDrawable) {
      final copy = selected.copyWith(
        position: selected.position + const Offset(30, 30),
      );
      _controller.addDrawables([copy]);
      _controller.selectObjectDrawable(copy);
    } else if (selected is ArrowDrawable) {
      final copy = selected.copyWith(
        position: selected.position + const Offset(30, 30),
      );
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

  Future<void> _sendCanvas(
    NoteitController notifier,
    LoveStoryTheme theme,
  ) async {
    final rp = ref.read(profileControllerProvider);
    final chatProvider = ref.read(loveChatControllerProvider.notifier);

    if (_controller.drawables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add some drawings, shapes, or notes to the canvas! 🎨',
          ),
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
      final file = File(
        '${directory.path}/canvas_export_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngData.buffer.asUint8List());

      // 2. Serialize objects to JSON CanvasDocument
      final doc = CanvasMapping.toDocument(
        _controller.drawables,
        _controller.value.background,
      );
      final jsonStr = jsonEncode(doc.toJson());

      // 3-6: create the note, mirror it into love chat, clear the draft --
      // see ScrapbookShareUseCase for why this is no longer inlined here.
      final useCase = ScrapbookShareUseCase(notifier, chatProvider, _draftStore);
      final result = await useCase.share(
        canvasJson: jsonStr,
        localImagePath: file.path,
        yourName: rp.yourName ?? 'Me',
      );

      switch (result) {
        case ScrapbookShareSuccess():
          _controller.clearDrawables();
          _tabController.animateTo(1); // Switch to history tab
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Canvas sent to partner! 🚀'),
                backgroundColor: Colors.green,
              ),
            );
          }
        case ScrapbookShareChatMirrorFailed():
          // The note itself was created successfully -- only the chat
          // mirror failed -- so this still counts as "sent" for the
          // canvas's own sake, but the user should know their partner
          // won't get a chat notification pointing at it.
          _controller.clearDrawables();
          _tabController.animateTo(1);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved to scrapbook, but couldn\'t notify chat: ${result.failure.message}'),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
        case ScrapbookShareNoteFailed():
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send: ${result.failure.message}'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
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
    _inlineTextController.dispose();
    _inlineTextFocusNode.dispose();
    _tabController.dispose();
    _controller.removeListener(_onControllerUpdated);
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final theme = themeState.currentLoveTheme;
    final noteitState = ref.watch(noteitControllerProvider);
    final noteitNotifier = ref.read(noteitControllerProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Scrapbook',
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
                  onPressed: _controller.canUndo
                      ? () => _controller.undo()
                      : null,
                  tooltip: 'Undo',
                ),
                IconButton(
                  icon: Icon(Icons.redo_rounded, color: theme.textColor),
                  onPressed: _controller.canRedo
                      ? () => _controller.redo()
                      : null,
                  tooltip: 'Redo',
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_sweep_rounded,
                    color: theme.textColor,
                  ),
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
        decoration: BoxDecoration(gradient: themeState.currentGradient),
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            physics:
                const NeverScrollableScrollPhysics(), // Prevent conflict with panning
            children: [
              _buildCanvasWorkspace(theme, noteitNotifier),
              _buildHistoryLog(theme, noteitState, noteitNotifier),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasWorkspace(LoveStoryTheme theme, NoteitController notifier) {
    final selectedObj = _controller.value.selectedObjectDrawable;
    if (selectedObj != _lastSelectedObj) {
      _lastSelectedObj = selectedObj;
      if (selectedObj != null) {
        _isPropertiesPanelExpanded = true;
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_isInlineEditing) return;
        setState(() {
          _isPropertiesPanelExpanded = false;
          _controller.deselectObjectDrawable();
        });
      },
      child: Stack(
        children: [
          // The Infinite Canvas
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 120,
              ), // Leave space for properties & toolbar
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
                      child: Stack(
                        children: [
                          RasterCanvas(controller: _controller),
                          if (_isInlineEditing) ...[
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () => _finishInlineEditing(),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(
                                    sigmaX: 3.0,
                                    sigmaY: 3.0,
                                  ),
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: TextField(
                                  controller: _inlineTextController,
                                  focusNode: _inlineTextFocusNode,
                                  autofocus: true,
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  textAlign: _textAlign,
                                  cursorColor: _brushColor,
                                  style: _getTextStyle(
                                    fontSize: _fontSize,
                                    color: _brushColor,
                                    isBold: _isBold,
                                    isItalic: _isItalic,
                                    isUnderline: _isUnderline,
                                    fontFamily: _activeFontFamily,
                                    highlightColor: _highlightColor,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: '',
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.check_circle_rounded,
                                  size: 28,
                                  color: Colors.greenAccent,
                                ),
                                onPressed: () => _finishInlineEditing(),
                                tooltip: 'Save Text',
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.cancel_rounded,
                                  size: 28,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () =>
                                    _finishInlineEditing(cancel: true),
                                tooltip: 'Cancel',
                              ),
                            ),
                          ],
                        ],
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
              child: GestureDetector(
                onTap: () {}, // Absorb taps inside toolbar
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.textColor.withValues(alpha: 0.15),
                    ),
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
                        icon: Icon(
                          selectedObj.locked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          color: theme.textColor,
                        ),
                        onPressed: () {
                          final updated = selectedObj.copyWith(
                            locked: !selectedObj.locked,
                          );
                          _controller.replaceDrawable(selectedObj, updated);
                          _controller.selectObjectDrawable(updated);
                        },
                        tooltip: selectedObj.locked
                            ? 'Unlock Object'
                            : 'Lock Object',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.flip_to_back_rounded,
                          color: theme.textColor,
                        ),
                        onPressed: () => _sendBackward(selectedObj),
                        tooltip: 'Send Backward',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.flip_to_front_rounded,
                          color: theme.textColor,
                        ),
                        onPressed: () => _bringForward(selectedObj),
                        tooltip: 'Bring Forward',
                      ),
                      if (selectedObj is TextDrawable)
                        IconButton(
                          icon: Icon(
                            Icons.edit_rounded,
                            color: theme.textColor,
                          ),
                          onPressed: () {
                            if (selectedObj is CustomTextDrawable) {
                              _startInlineEditing(
                                existingDrawable: selectedObj,
                              );
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
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.redAccent,
                        ),
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
            ),

          // Floating Send Button
          Positioned(
            bottom: 110,
            right: 20,
            child: GestureDetector(
              onTap: () {}, // Absorb taps
              child: FloatingActionButton.extended(
                onPressed: _isSaving
                    ? null
                    : () => _sendCanvas(notifier, theme),
                backgroundColor: theme.accentColor,
                elevation: 4,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  'Send',
                  style: AppTypography.body(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Floating Font Size Slider (Only visible when adding/editing text)
          if (_isPropertiesPanelExpanded &&
              (_activeMode == 'text' || selectedObj is TextDrawable))
            Positioned(
              left: 12,
              top: 160,
              bottom: 290,
              child: GestureDetector(
                onTap: () {}, // Absorb taps
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.textColor.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.text_fields_rounded,
                        color: theme.textColor,
                        size: 16,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(selectedObj is TextDrawable ? (selectedObj.style.fontSize ?? _fontSize) : _fontSize).round()}',
                        style: AppTypography.body(
                          color: theme.textColor,
                          fontSize: 10,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value: selectedObj is TextDrawable
                                ? (selectedObj.style.fontSize ?? _fontSize)
                                : _fontSize,
                            min: 10.0,
                            max: 80.0,
                            activeColor: theme.accentColor,
                            inactiveColor: theme.textColor.withValues(
                              alpha: 0.1,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _fontSize = val;
                                if (selectedObj is TextDrawable) {
                                  final updated = selectedObj.copyWith(
                                    style: selectedObj.style.copyWith(
                                      fontSize: val,
                                    ),
                                  );
                                  _controller.replaceDrawable(
                                    selectedObj,
                                    updated,
                                  );
                                  _controller.selectObjectDrawable(updated);
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Configuration Sheets
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {}, // Absorb taps
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isPropertiesPanelExpanded) ...[
                    if (selectedObj != null)
                      (selectedObj is TextDrawable
                          ? _buildTextPropertiesPanel(theme, selectedObj)
                          : _buildPropertiesPanel(theme))
                    else if (_activeMode == 'text')
                      _buildTextPropertiesPanel(theme, null)
                    else if (_activeMode != 'select')
                      _buildPropertiesPanel(theme),
                  ],

                  _buildBottomFloatingToolbar(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPropertiesPanel(
    LoveStoryTheme theme,
    TextDrawable? selectedText,
  ) {
    final bool isBold = selectedText != null
        ? (selectedText.style.fontWeight == FontWeight.bold)
        : _isBold;
    final bool isItalic = selectedText != null
        ? (selectedText.style.fontStyle == FontStyle.italic)
        : _isItalic;
    final bool isUnderline = selectedText != null
        ? (selectedText.style.decoration == TextDecoration.underline)
        : _isUnderline;
    final Color activeColor = selectedText != null
        ? (selectedText.style.color ?? _brushColor)
        : _brushColor;
    final Color activeHighlight = selectedText != null
        ? (selectedText.style.backgroundColor ?? Colors.transparent)
        : _highlightColor;
    final TextAlign activeAlign =
        (selectedText != null && selectedText is CustomTextDrawable)
        ? selectedText.textAlign
        : _textAlign;

    IconData getAlignIcon(TextAlign align) {
      switch (align) {
        case TextAlign.left:
          return Icons.format_align_left_rounded;
        case TextAlign.right:
          return Icons.format_align_right_rounded;
        case TextAlign.center:
        default:
          return Icons.format_align_center_rounded;
      }
    }

    TextAlign getNextAlign(TextAlign align) {
      switch (align) {
        case TextAlign.left:
          return TextAlign.center;
        case TextAlign.center:
          return TextAlign.right;
        case TextAlign.right:
        default:
          return TextAlign.left;
      }
    }

    String matchedFont = _activeFontFamily;
    if (selectedText != null && selectedText.style.fontFamily != null) {
      final family = selectedText.style.fontFamily!
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
      for (final f in _fontFamilies) {
        final cleanF = f.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        if (family.contains(cleanF)) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Font Family selector list
          SizedBox(
            height: 36,
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
                    color: isSelected
                        ? theme.accentColor
                        : theme.textColor.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  );
                } catch (_) {
                  fontStyle = TextStyle(
                    fontFamily: font,
                    color: isSelected
                        ? theme.accentColor
                        : theme.textColor.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(font, style: fontStyle),
                    selected: isSelected,
                    selectedColor: theme.accentColor.withValues(alpha: 0.15),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: isSelected
                          ? theme.accentColor
                          : theme.textColor.withValues(alpha: 0.15),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _activeFontFamily = font;
                          if (selectedText != null) {
                            final updated = selectedText.copyWith(
                              style: _getTextStyle(
                                fontSize: selectedText.style.fontSize ?? 20.0,
                                color: selectedText.style.color ?? _brushColor,
                                isBold:
                                    selectedText.style.fontWeight ==
                                    FontWeight.bold,
                                isItalic:
                                    selectedText.style.fontStyle ==
                                    FontStyle.italic,
                                isUnderline:
                                    selectedText.style.decoration ==
                                    TextDecoration.underline,
                                fontFamily: font,
                                highlightColor: activeHighlight,
                              ),
                            );
                            _controller.replaceDrawable(selectedText, updated);
                            _controller.selectObjectDrawable(updated);
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

          // Row 2: Text Color Selection
          Row(
            children: [
              Text(
                'Text:',
                style: AppTypography.body(
                  color: theme.textColor,
                  fontSize: 12,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 32,
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
                                _brushColor = pickedColor;
                                if (selectedText != null) {
                                  final updated = selectedText.copyWith(
                                    style: _getTextStyle(
                                      fontSize:
                                          selectedText.style.fontSize ?? 20.0,
                                      color: pickedColor,
                                      isBold:
                                          selectedText.style.fontWeight ==
                                          FontWeight.bold,
                                      isItalic:
                                          selectedText.style.fontStyle ==
                                          FontStyle.italic,
                                      isUnderline:
                                          selectedText.style.decoration ==
                                          TextDecoration.underline,
                                      fontFamily: matchedFont,
                                      highlightColor: activeHighlight,
                                    ),
                                  );
                                  _controller.replaceDrawable(
                                    selectedText,
                                    updated,
                                  );
                                  _controller.selectObjectDrawable(updated);
                                }
                              });
                            }
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.textColor.withValues(alpha: 0.3),
                                width: 1.2,
                              ),
                              gradient: const SweepGradient(
                                colors: [
                                  Colors.red,
                                  Colors.yellow,
                                  Colors.green,
                                  Colors.blue,
                                  Colors.red,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: theme.textColor,
                              size: 16,
                            ),
                          ),
                        );
                      }

                      final color = _paletteColors[i];
                      final isSelected =
                          activeColor.toARGB32() == color.toARGB32();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _brushColor = color;
                              if (selectedText != null) {
                                final updated = selectedText.copyWith(
                                  style: _getTextStyle(
                                    fontSize:
                                        selectedText.style.fontSize ?? 20.0,
                                    color: color,
                                    isBold:
                                        selectedText.style.fontWeight ==
                                        FontWeight.bold,
                                    isItalic:
                                        selectedText.style.fontStyle ==
                                        FontStyle.italic,
                                    isUnderline:
                                        selectedText.style.decoration ==
                                        TextDecoration.underline,
                                    fontFamily: matchedFont,
                                    highlightColor: activeHighlight,
                                  ),
                                );
                                _controller.replaceDrawable(
                                  selectedText,
                                  updated,
                                );
                                _controller.selectObjectDrawable(updated);
                              }
                            });
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? theme.textColor
                                    : Colors.transparent,
                                width: 1.8,
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
          const SizedBox(height: 8),

          // Row 3: Highlight Color Selection
          Row(
            children: [
              Text(
                'Highlight:',
                style: AppTypography.body(
                  color: theme.textColor,
                  fontSize: 12,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _highlightColors.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == _highlightColors.length) {
                        return GestureDetector(
                          onTap: () async {
                            final pickedColor = await showDialog<Color>(
                              context: context,
                              builder: (ctx) => ColorPickerDialog(
                                initialColor:
                                    activeHighlight == Colors.transparent
                                    ? Colors.yellow.withValues(alpha: 0.3)
                                    : activeHighlight,
                                theme: theme,
                              ),
                            );
                            if (pickedColor != null) {
                              setState(() {
                                _highlightColor = pickedColor;
                                if (selectedText != null) {
                                  final updated = selectedText.copyWith(
                                    style: _getTextStyle(
                                      fontSize:
                                          selectedText.style.fontSize ?? 20.0,
                                      color: activeColor,
                                      isBold:
                                          selectedText.style.fontWeight ==
                                          FontWeight.bold,
                                      isItalic:
                                          selectedText.style.fontStyle ==
                                          FontStyle.italic,
                                      isUnderline:
                                          selectedText.style.decoration ==
                                          TextDecoration.underline,
                                      fontFamily: matchedFont,
                                      highlightColor: pickedColor,
                                    ),
                                  );
                                  _controller.replaceDrawable(
                                    selectedText,
                                    updated,
                                  );
                                  _controller.selectObjectDrawable(updated);
                                }
                              });
                            }
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.textColor.withValues(alpha: 0.3),
                                width: 1.2,
                              ),
                              gradient: const SweepGradient(
                                colors: [
                                  Colors.red,
                                  Colors.yellow,
                                  Colors.green,
                                  Colors.blue,
                                  Colors.red,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: theme.textColor,
                              size: 16,
                            ),
                          ),
                        );
                      }

                      final color = _highlightColors[i];
                      final isSelected =
                          activeHighlight.toARGB32() == color.toARGB32();
                      final isTransparent = color == Colors.transparent;

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _highlightColor = color;
                              if (selectedText != null) {
                                final updated = selectedText.copyWith(
                                  style: _getTextStyle(
                                    fontSize:
                                        selectedText.style.fontSize ?? 20.0,
                                    color: activeColor,
                                    isBold:
                                        selectedText.style.fontWeight ==
                                        FontWeight.bold,
                                    isItalic:
                                        selectedText.style.fontStyle ==
                                        FontStyle.italic,
                                    isUnderline:
                                        selectedText.style.decoration ==
                                        TextDecoration.underline,
                                    fontFamily: matchedFont,
                                    highlightColor: color,
                                  ),
                                );
                                _controller.replaceDrawable(
                                  selectedText,
                                  updated,
                                );
                                _controller.selectObjectDrawable(updated);
                              }
                            });
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isTransparent
                                  ? Colors.grey.withValues(alpha: 0.2)
                                  : color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? theme.textColor
                                    : Colors.transparent,
                                width: 1.8,
                              ),
                            ),
                            child: isTransparent
                                ? Icon(
                                    Icons.format_color_reset_rounded,
                                    size: 14,
                                    color: theme.textColor.withValues(
                                      alpha: 0.6,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 4: Formatting controls
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.format_bold,
                  color: isBold
                      ? theme.accentColor
                      : theme.textColor.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  setState(() {
                    _isBold = !_isBold;
                    if (selectedText != null) {
                      final updated = selectedText.copyWith(
                        style: _getTextStyle(
                          fontSize: selectedText.style.fontSize ?? 20.0,
                          color: activeColor,
                          isBold: !isBold,
                          isItalic: isItalic,
                          isUnderline: isUnderline,
                          fontFamily: matchedFont,
                          highlightColor: activeHighlight,
                        ),
                      );
                      _controller.replaceDrawable(selectedText, updated);
                      _controller.selectObjectDrawable(updated);
                    }
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.format_italic,
                  color: isItalic
                      ? theme.accentColor
                      : theme.textColor.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  setState(() {
                    _isItalic = !_isItalic;
                    if (selectedText != null) {
                      final updated = selectedText.copyWith(
                        style: _getTextStyle(
                          fontSize: selectedText.style.fontSize ?? 20.0,
                          color: activeColor,
                          isBold: isBold,
                          isItalic: !isItalic,
                          isUnderline: isUnderline,
                          fontFamily: matchedFont,
                          highlightColor: activeHighlight,
                        ),
                      );
                      _controller.replaceDrawable(selectedText, updated);
                      _controller.selectObjectDrawable(updated);
                    }
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.format_underlined,
                  color: isUnderline
                      ? theme.accentColor
                      : theme.textColor.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  setState(() {
                    _isUnderline = !_isUnderline;
                    if (selectedText != null) {
                      final updated = selectedText.copyWith(
                        style: _getTextStyle(
                          fontSize: selectedText.style.fontSize ?? 20.0,
                          color: activeColor,
                          isBold: isBold,
                          isItalic: isItalic,
                          isUnderline: !isUnderline,
                          fontFamily: matchedFont,
                          highlightColor: activeHighlight,
                        ),
                      );
                      _controller.replaceDrawable(selectedText, updated);
                      _controller.selectObjectDrawable(updated);
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(getAlignIcon(activeAlign), color: theme.accentColor),
                onPressed: () {
                  final nextAlign = getNextAlign(activeAlign);
                  setState(() {
                    _textAlign = nextAlign;
                    if (selectedText != null &&
                        selectedText is CustomTextDrawable) {
                      final renderBox =
                          _controller.painterKey.currentContext
                                  ?.findRenderObject()
                              as RenderBox?;
                      final canvasWidth = renderBox?.size.width ?? 600.0;
                      final textWidth =
                          selectedText.getSize().width * selectedText.scale;

                      double newX = selectedText.position.dx;
                      const double margin = 20.0;

                      if (nextAlign == TextAlign.left) {
                        newX = (textWidth / 2) + margin;
                      } else if (nextAlign == TextAlign.center) {
                        newX = canvasWidth / 2;
                      } else if (nextAlign == TextAlign.right) {
                        newX = canvasWidth - (textWidth / 2) - margin;
                      }

                      final updated = selectedText.copyWith(
                        textAlign: nextAlign,
                        position: Offset(newX, selectedText.position.dy),
                      );
                      _controller.replaceDrawable(selectedText, updated);
                      _controller.selectObjectDrawable(updated);
                    }
                  });
                },
                tooltip: 'Cycle Text Alignment',
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
                    DropdownMenuItem(
                      value: 'rectangle',
                      child: Text('Rectangle'),
                    ),
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
          if (_activeMode != 'eraser') ...[
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
                          border: Border.all(
                            color: theme.textColor.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          gradient: const SweepGradient(
                            colors: [
                              Colors.red,
                              Colors.yellow,
                              Colors.green,
                              Colors.blue,
                              Colors.red,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: theme.textColor,
                          size: 18,
                        ),
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
                            color: isSelected
                                ? theme.textColor
                                : Colors.transparent,
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
              _buildToolbarButton(
                Icons.near_me_rounded,
                'select',
                'Select Object',
              ),
              _buildToolbarButton(Icons.edit_rounded, 'pen', 'Pen'),
              _buildToolbarButton(Icons.brush_rounded, 'pencil', 'Pencil'),
              _buildToolbarButton(
                Icons.border_color_rounded,
                'marker',
                'Marker',
              ),
              _buildToolbarButton(
                Icons.cleaning_services_rounded,
                'eraser',
                'Eraser',
              ),
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
    final theme = ref.watch(themeControllerProvider).currentLoveTheme;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_activeMode == mode) {
              _isPropertiesPanelExpanded = !_isPropertiesPanelExpanded;
            } else {
              _activeMode = mode;
              _isPropertiesPanelExpanded = true;
              _updateSettings();
            }
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
            color: isSelected
                ? Colors.white
                : theme.textColor.withValues(alpha: 0.7),
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
              style: AppTypography.heading(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Background Template:',
                  style: AppTypography.body(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBgOptionButton(
                      setDialogState,
                      'color',
                      'Solid color',
                      Colors.white,
                    ),
                    _buildBgOptionButton(
                      setDialogState,
                      'grid',
                      'Grid Lines',
                      Colors.white,
                    ),
                    _buildBgOptionButton(
                      setDialogState,
                      'dots',
                      'Dot Grid',
                      Colors.white,
                    ),
                    _buildBgOptionButton(
                      setDialogState,
                      'notebook',
                      'Notebook',
                      const Color(0xFFF9F9FB),
                    ),
                    _buildBgOptionButton(
                      setDialogState,
                      'gradient',
                      'Gradient',
                      Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Solid Color Picker:',
                  style: AppTypography.body(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._paletteColors.map((color) {
                      final isSelectedColor =
                          _bgType == 'color' &&
                          _bgColor.toARGB32() == color.toARGB32();
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
                              color: isSelectedColor
                                  ? theme.textColor
                                  : Colors.grey.withValues(alpha: 0.3),
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
                          border: Border.all(
                            color: theme.textColor.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          gradient: const SweepGradient(
                            colors: [
                              Colors.red,
                              Colors.yellow,
                              Colors.green,
                              Colors.blue,
                              Colors.red,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: theme.textColor,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Done',
                  style: AppTypography.button(color: theme.accentColor),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBgOptionButton(
    StateSetter setDialogState,
    String type,
    String label,
    Color previewColor,
  ) {
    final isSelected = _bgType == type;
    final theme = ref.watch(themeControllerProvider).currentLoveTheme;

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
        side: BorderSide(
          color: isSelected
              ? theme.accentColor
              : theme.textColor.withValues(alpha: 0.2),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  // 5. HISTORY LOG
  Widget _buildHistoryLog(LoveStoryTheme theme, NoteitState state, NoteitController notifier) {
    final list = state.visibleNotes;
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
                  style: AppTypography.heading(
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
                      notifier.deleteNote(item.id);
                    },
                  ),
                ],
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color:
                  item.backgroundColor ??
                  theme.textColor.withValues(alpha: 0.05),
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
                  style: AppTypography.heading(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(
                  'This canvas note couldn\'t be sent to your partner. Would you like to try sending it again?',
                  style: AppTypography.body(
                    color: theme.textColor.withValues(alpha: 0.8),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: AppTypography.button(
                        color: theme.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      NoteitSyncManager.instance.retryTask(item.id);
                    },
                    child: Text(
                      'Retry Now',
                      style: AppTypography.button(color: theme.accentColor),
                    ),
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
                border: Border.all(
                  color: theme.textColor.withValues(alpha: 0.2),
                  width: 2,
                ),
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
      return StorageImage(
        bucket: StorageBuckets.loveNotes,
        storageRef: item.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    // Fallback: Legacy drawings
    if (item.type == NoteitType.drawing) {
      return CustomPaint(
        painter: ScaleDrawingPainter(
          colorfulStrokes: NoteitItem.deserializeColorfulStrokes(item.content, Colors.white),
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
