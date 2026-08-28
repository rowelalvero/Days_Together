import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:days_together/features/chat/love_chat_controller.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/scrapbook/data/noteit_draft_store.dart';
import 'package:days_together/features/scrapbook/domain/scrapbook_share_use_case.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/features/scrapbook/presentation/components/noteit_canvas_viewport.dart';
import 'package:days_together/features/scrapbook/presentation/components/noteit_floating_toolbar.dart';
import 'package:days_together/features/scrapbook/presentation/components/noteit_history_panel.dart';
import 'package:days_together/features/scrapbook/presentation/custom_backgrounds.dart';
import 'package:days_together/features/scrapbook/presentation/dialogs/noteit_background_dialog.dart';
import 'package:days_together/features/scrapbook/presentation/sheets/noteit_brush_properties_panel.dart';
import 'package:days_together/features/scrapbook/presentation/sheets/noteit_text_properties_panel.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/services/permission_service.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/utils/canvas_mapping.dart';

/// NoteIt / Scrapbook interactive canvas screen.
/// Coordinates the canvas viewport, floating toolbars, rich text editing,
/// background templates, and shared note history feed.
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

  // Active Modes: 'select', 'pen', 'pencil', 'marker', 'eraser', 'shapes', 'text'
  String _activeMode = 'pen';
  bool _isPropertiesPanelExpanded = true;
  ObjectDrawable? _lastSelectedObj;
  String _activeShape = 'rectangle';

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
  String _bgType = 'color';
  Color _bgColor = Colors.white;

  bool _isSaving = false;

  final NoteitDraftStore _draftStore = const NoteitDraftStore();

  final List<Color> _paletteColors = [
    Colors.black,
    const Color(0xFFFF4D6D),
    const Color(0xFFFF85A1),
    const Color(0xFFFFB3C1),
    const Color(0xFF00B4D8),
    const Color(0xFF9D4EDD),
    const Color(0xFFD4AF37),
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
    _controller = PainterController();
    _controller.settings = PainterSettings(
      freeStyle: FreeStyleSettings(
        color: _brushColor,
        strokeWidth: _strokeWidth,
        mode: FreeStyleMode.draw,
      ),
      shape: ShapeSettings(
        paint: Paint()
          ..color = _brushColor
          ..strokeWidth = _strokeWidth
          ..style = PaintingStyle.stroke,
        drawOnce: true,
      ),
      scale: const ScaleSettings(
        enabled: true,
        minScale: 0.5,
        maxScale: 4.0,
      ),
    );
    _updateBackground();
    _controller.addListener(_onControllerUpdated);
  }

  void _onControllerUpdated() {
    if (!mounted) return;
    _saveDraft();
    setState(() {});
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

    try {
      final drawables = await CanvasMapping.toDrawables(doc);
      if (!mounted) return;

      setState(() {
        _controller.clearDrawables();
        _controller.addDrawables(drawables);
        _bgType = doc.background.type;
        if (doc.background.color != null) {
          _bgColor = Color(doc.background.color!);
        }
        _updateBackground();
      });
    } catch (e) {
      debugPrint('Error restoring canvas draft: $e');
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
          colors: [Color(0xFFFFCCD5), Color(0xFFFFF0F3)],
        );
        break;
      case 'grid':
        _controller.background = GridBackgroundDrawable(
          backgroundColor: _bgColor,
          gridColor: Colors.blueGrey.withValues(alpha: 0.2),
          step: 25.0,
        );
        break;
      case 'dots':
        _controller.background = DotsBackgroundDrawable(
          backgroundColor: _bgColor,
          dotColor: Colors.blueGrey.withValues(alpha: 0.25),
          step: 20.0,
        );
        break;
      case 'notebook':
        _controller.background = NotebookBackgroundDrawable(
          backgroundColor: const Color(0xFFF9F9FB),
          lineColor: Colors.blue.withValues(alpha: 0.15),
          marginColor: Colors.red.withValues(alpha: 0.2),
          step: 28.0,
        );
        break;
      case 'color':
      default:
        _controller.background = ColorBackgroundDrawable(color: _bgColor);
        break;
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

        final hiddenDrawable = existingDrawable.copyWith(hidden: true);
        _controller.replaceDrawable(existingDrawable, hiddenDrawable);
        _editingTextDrawable = hiddenDrawable;
        _controller.deselectObjectDrawable();
      } else {
        _editingTextDrawable = null;
        _isEditingExistingText = false;
        _inlineTextController.clear();

        final tempDrawable = CustomTextDrawable(
          text: '',
          position: Offset(canvasWidth / 2, centerY),
          style: getNoteitTextStyle(
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
          final restored = drawable.copyWith(hidden: false);
          _controller.replaceDrawable(drawable, restored);
          _controller.selectObjectDrawable(restored);
        } else {
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
          style: getNoteitTextStyle(
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

  Future<void> _sendCanvas(NoteitController notifier, LoveStoryTheme theme) async {
    final rp = ref.read(profileControllerProvider);
    final chatProvider = ref.read(loveChatControllerProvider.notifier);

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
      final image = await _controller.renderImage(const Size(1000, 1000));
      final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (pngData == null) throw Exception('Failed to render PNG data');

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/canvas_export_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngData.buffer.asUint8List());

      final doc = CanvasMapping.toDocument(
        _controller.drawables,
        _controller.value.background,
      );
      final jsonStr = jsonEncode(doc.toJson());

      final useCase = ScrapbookShareUseCase(notifier, chatProvider, _draftStore);
      final result = await useCase.share(
        canvasJson: jsonStr,
        localImagePath: file.path,
        yourName: rp.yourName ?? 'Me',
      );

      switch (result) {
        case ScrapbookShareSuccess():
          _controller.clearDrawables();
          _tabController.animateTo(1);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Canvas sent to partner! 🚀'),
                backgroundColor: Colors.green,
              ),
            );
          }
        case ScrapbookShareChatMirrorFailed():
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

  void _showBackgroundSettingsDialog(LoveStoryTheme theme) {
    showDialog(
      context: context,
      builder: (ctx) => NoteitBackgroundDialog(
        theme: theme,
        initialBgType: _bgType,
        initialBgColor: _bgColor,
        paletteColors: _paletteColors,
        onBackgroundChanged: (bgType, bgColor) {
          setState(() {
            _bgType = bgType;
            _bgColor = bgColor;
            _updateBackground();
          });
        },
      ),
    );
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

  Widget _buildConfigurationSheets(LoveStoryTheme theme) {
    final selectedObj = _controller.value.selectedObjectDrawable;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isPropertiesPanelExpanded) ...[
          if (selectedObj != null)
            (selectedObj is TextDrawable
                ? NoteitTextPropertiesPanel(
                    theme: theme,
                    selectedText: selectedObj,
                    activeFontFamily: _activeFontFamily,
                    fontFamilies: _fontFamilies,
                    brushColor: _brushColor,
                    paletteColors: _paletteColors,
                    highlightColor: _highlightColor,
                    highlightColors: _highlightColors,
                    isBold: _isBold,
                    isItalic: _isItalic,
                    isUnderline: _isUnderline,
                    textAlign: _textAlign,
                    controller: _controller,
                    onFontFamilyChanged: (font) => setState(() => _activeFontFamily = font),
                    onTextColorChanged: (color) => setState(() => _brushColor = color),
                    onHighlightColorChanged: (color) => setState(() => _highlightColor = color),
                    onToggleBold: () => setState(() => _isBold = !_isBold),
                    onToggleItalic: () => setState(() => _isItalic = !_isItalic),
                    onToggleUnderline: () => setState(() => _isUnderline = !_isUnderline),
                    onAlignmentChanged: (align) => setState(() => _textAlign = align),
                  )
                : NoteitBrushPropertiesPanel(
                    theme: theme,
                    activeMode: _activeMode,
                    strokeWidth: _strokeWidth,
                    activeShape: _activeShape,
                    brushColor: _brushColor,
                    paletteColors: _paletteColors,
                    onStrokeWidthChanged: (val) => setState(() {
                      _strokeWidth = val;
                      _updateSettings();
                    }),
                    onShapeChanged: (val) => setState(() {
                      _activeShape = val;
                      _updateSettings();
                    }),
                    onBrushColorChanged: (color) => setState(() {
                      _brushColor = color;
                      _updateSettings();
                    }),
                  ))
          else if (_activeMode == 'text')
            NoteitTextPropertiesPanel(
              theme: theme,
              selectedText: null,
              activeFontFamily: _activeFontFamily,
              fontFamilies: _fontFamilies,
              brushColor: _brushColor,
              paletteColors: _paletteColors,
              highlightColor: _highlightColor,
              highlightColors: _highlightColors,
              isBold: _isBold,
              isItalic: _isItalic,
              isUnderline: _isUnderline,
              textAlign: _textAlign,
              controller: _controller,
              onFontFamilyChanged: (font) => setState(() => _activeFontFamily = font),
              onTextColorChanged: (color) => setState(() => _brushColor = color),
              onHighlightColorChanged: (color) => setState(() => _highlightColor = color),
              onToggleBold: () => setState(() => _isBold = !_isBold),
              onToggleItalic: () => setState(() => _isItalic = !_isItalic),
              onToggleUnderline: () => setState(() => _isUnderline = !_isUnderline),
              onAlignmentChanged: (align) => setState(() => _textAlign = align),
            )
          else if (_activeMode != 'select')
            NoteitBrushPropertiesPanel(
              theme: theme,
              activeMode: _activeMode,
              strokeWidth: _strokeWidth,
              activeShape: _activeShape,
              brushColor: _brushColor,
              paletteColors: _paletteColors,
              onStrokeWidthChanged: (val) => setState(() {
                _strokeWidth = val;
                _updateSettings();
              }),
              onShapeChanged: (val) => setState(() {
                _activeShape = val;
                _updateSettings();
              }),
              onBrushColorChanged: (color) => setState(() {
                _brushColor = color;
                _updateSettings();
              }),
            ),
        ],
        NoteitFloatingToolbar(
          theme: theme,
          activeMode: _activeMode,
          isPropertiesPanelExpanded: _isPropertiesPanelExpanded,
          onModeChanged: (mode) {
            setState(() {
              _activeMode = mode;
              _isPropertiesPanelExpanded = true;
              _updateSettings();
            });
          },
          onToggleProperties: () {
            setState(() {
              _isPropertiesPanelExpanded = !_isPropertiesPanelExpanded;
            });
          },
          onAddText: () => _startInlineEditing(),
          onImportImage: _importImage,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final theme = themeState.currentLoveTheme;
    final noteitState = ref.watch(noteitControllerProvider);
    final noteitNotifier = ref.read(noteitControllerProvider.notifier);

    final selectedObj = _controller.value.selectedObjectDrawable;
    if (selectedObj != _lastSelectedObj) {
      _lastSelectedObj = selectedObj;
      if (selectedObj != null) {
        _isPropertiesPanelExpanded = true;
      }
    }

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
                  onPressed: _controller.canUndo ? () => _controller.undo() : null,
                  tooltip: 'Undo',
                ),
                IconButton(
                  icon: Icon(Icons.redo_rounded, color: theme.textColor),
                  onPressed: _controller.canRedo ? () => _controller.redo() : null,
                  tooltip: 'Redo',
                ),
                IconButton(
                  icon: Icon(Icons.layers_rounded, color: theme.textColor),
                  onPressed: () => _showBackgroundSettingsDialog(theme),
                  tooltip: 'Background Settings',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: theme.textColor),
                  onPressed: () => _clearCanvas(theme),
                  tooltip: 'Clear Canvas',
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.accentColor,
          labelColor: theme.accentColor,
          unselectedLabelColor: theme.textColor.withValues(alpha: 0.5),
          labelStyle: AppTypography.body(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Canvas', icon: Icon(Icons.draw_rounded, size: 20)),
            Tab(text: 'History', icon: Icon(Icons.history_rounded, size: 20)),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor,
              theme.secondaryColor,
              theme.backgroundColor,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              NoteitCanvasViewport(
                controller: _controller,
                theme: theme,
                isInlineEditing: _isInlineEditing,
                inlineTextController: _inlineTextController,
                inlineTextFocusNode: _inlineTextFocusNode,
                onFinishInlineEditing: _finishInlineEditing,
                onCancelInlineEditing: () => _finishInlineEditing(cancel: true),
                fontSize: _fontSize,
                brushColor: _brushColor,
                isBold: _isBold,
                isItalic: _isItalic,
                isUnderline: _isUnderline,
                activeFontFamily: _activeFontFamily,
                highlightColor: _highlightColor,
                textAlign: _textAlign,
                isPropertiesPanelExpanded: _isPropertiesPanelExpanded,
                activeMode: _activeMode,
                isSaving: _isSaving,
                onSendCanvas: () => _sendCanvas(noteitNotifier, theme),
                onDeselect: () {
                  setState(() {
                    _isPropertiesPanelExpanded = false;
                    _controller.deselectObjectDrawable();
                  });
                },
                onStartInlineEditing: (d) => _startInlineEditing(existingDrawable: d),
                onDuplicateSelected: _duplicateSelected,
                onBringForward: _bringForward,
                onSendBackward: _sendBackward,
                onFontSizeChanged: (val) => setState(() => _fontSize = val),
                bottomConfigurationSheets: _buildConfigurationSheets(theme),
              ),
              NoteitHistoryPanel(
                theme: theme,
                state: noteitState,
                notifier: noteitNotifier,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
