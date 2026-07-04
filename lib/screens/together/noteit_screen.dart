import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:image_picker/image_picker.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/noteit_provider.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/services/permission_service.dart';
import 'package:days_together/services/noteit_sync_manager.dart';
import 'package:days_together/widgets/color_picker_dialog.dart';
import 'package:days_together/widgets/raster_canvas.dart';
import 'package:days_together/widgets/text_overlay_widget.dart';
import 'package:days_together/widgets/rich_text_editor_overlay.dart';

class NoteitScreen extends StatefulWidget {
  const NoteitScreen({super.key});

  @override
  State<NoteitScreen> createState() => _NoteitScreenState();
}

class _NoteitScreenState extends State<NoteitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<RasterCanvasState> _canvasKey = GlobalKey<RasterCanvasState>();

  // Canvas State
  Color _canvasBgColor = Colors.white;
  String? _pickedPhotoPath;
  String? _drawingLayerBase64;
  final List<CanvasTextOverlay> _textOverlays = [];
  bool _canUndo = false;
  bool _canRedo = false;

  // Active Tool & Brush Options
  CanvasTool _activeTool = CanvasTool.pen;
  double _strokeWidth = 4.0;
  Color _brushColor = const Color(0xFFFF4D6D);

  final List<Color> _paletteColors = [
    const Color(0xFFFF4D6D), // pink
    const Color(0xFFFF85A1), // light pink
    const Color(0xFFFFB3C1), // soft pink
    const Color(0xFF00B4D8), // cyan
    const Color(0xFF9D4EDD), // purple
    const Color(0xFFD4AF37), // gold
    Colors.white,
    Colors.greenAccent,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _clearAllCanvas() {
    setState(() {
      _canvasBgColor = Colors.white;
      _pickedPhotoPath = null;
      _drawingLayerBase64 = null;
      _textOverlays.clear();
      _canUndo = false;
      _canRedo = false;
      _canvasKey.currentState?.clearAll();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final permissionService = PermissionService();
    if (!mounted) return;
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
        maxWidth: 1500,
        maxHeight: 1500,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _pickedPhotoPath = picked.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _openCustomColorPicker(LoveStoryTheme theme) async {
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
      });
    }
  }

  Future<void> _addTextOverlay(LoveStoryTheme theme) async {
    final newOverlay = await Navigator.push<CanvasTextOverlay>(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (context, _, __) => RichTextEditorOverlay(
          theme: theme,
        ),
      ),
    );
    if (newOverlay != null) {
      setState(() {
        _textOverlays.add(newOverlay);
      });
    }
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
          'Doodles & Notes',
          style: AppTypography.cormorant(
            fontSize: 28,
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.accentColor,
          labelColor: theme.textColor,
          unselectedLabelColor: theme.textColor.withValues(alpha: 0.5),
          tabs: const [
            Tab(text: '🎨 Editor'),
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
            children: [
              _buildCanvasEditor(theme, provider),
              _buildHistoryLog(theme, provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasEditor(LoveStoryTheme theme, NoteitProvider provider) {
    return Column(
      children: [
        // Top options: Undo, Clear, Tool sizes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: theme.textColor),
                onPressed: _clearAllCanvas,
                tooltip: 'Clear Canvas',
              ),
              IconButton(
                icon: Icon(
                  Icons.undo_rounded,
                  color: _canUndo ? theme.textColor : theme.textColor.withValues(alpha: 0.3),
                ),
                onPressed: _canUndo ? () => _canvasKey.currentState?.undo() : null,
                tooltip: 'Undo',
              ),
              IconButton(
                icon: Icon(
                  Icons.redo_rounded,
                  color: _canRedo ? theme.textColor : theme.textColor.withValues(alpha: 0.3),
                ),
                onPressed: _canRedo ? () => _canvasKey.currentState?.redo() : null,
                tooltip: 'Redo',
              ),
              IconButton(
                icon: Icon(Icons.text_fields_rounded, color: theme.textColor),
                onPressed: () => _addTextOverlay(theme),
                tooltip: 'Add Text',
              ),
              IconButton(
                icon: Icon(Icons.photo_library_outlined, color: theme.textColor),
                onPressed: () => _pickImage(ImageSource.gallery),
                tooltip: 'Background Photo',
              ),
              if (_pickedPhotoPath != null)
                IconButton(
                  icon: const Icon(Icons.no_photography_outlined, color: Colors.redAccent),
                  onPressed: () => setState(() => _pickedPhotoPath = null),
                  tooltip: 'Remove Background Photo',
                ),
              const Spacer(),
              Text(
                'Size:',
                style: AppTypography.body(
                  color: theme.textColor.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              SizedBox(
                width: 90,
                child: Slider(
                  value: _strokeWidth,
                  min: 1.0,
                  max: 20.0,
                  activeColor: theme.accentColor,
                  inactiveColor: theme.textColor.withValues(alpha: 0.1),
                  onChanged: (val) {
                    setState(() {
                      _strokeWidth = val;
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        // Square Canvas Stack
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: _canvasBgColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.textColor.withValues(alpha: 0.15),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Background Photo
                        if (_pickedPhotoPath != null)
                          Positioned.fill(
                            child: Image.file(
                              File(_pickedPhotoPath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        
                        // Drawing Layer
                        Positioned.fill(
                          child: RasterCanvas(
                            key: _canvasKey,
                            brushColor: _brushColor,
                            strokeWidth: _strokeWidth,
                            activeTool: _activeTool,
                            initialBase64: _drawingLayerBase64,
                            onDrawingLayerChanged: (base64) {
                              _drawingLayerBase64 = base64;
                            },
                            onCanvasBgColorChanged: (color) {
                              setState(() {
                                _canvasBgColor = color;
                              });
                            },
                            onUndoRedoStateChanged: (canUndo, canRedo) {
                              setState(() {
                                _canUndo = canUndo;
                                _canRedo = canRedo;
                              });
                            },
                          ),
                        ),

                        // Text Overlays
                        ..._textOverlays.map((overlay) {
                          return TextOverlayWidget(
                            overlay: overlay,
                            onUpdate: (updated) {
                              setState(() {
                                final idx = _textOverlays.indexWhere((o) => o.id == updated.id);
                                if (idx != -1) {
                                  _textOverlays[idx] = updated;
                                }
                              });
                            },
                            onTap: () async {
                              final updatedOverlay = await Navigator.push<CanvasTextOverlay>(
                                context,
                                PageRouteBuilder(
                                  opaque: false,
                                  barrierColor: Colors.black54,
                                  pageBuilder: (context, _, __) => RichTextEditorOverlay(
                                    initialOverlay: overlay,
                                    theme: theme,
                                  ),
                                ),
                              );
                              if (updatedOverlay != null) {
                                setState(() {
                                  final idx = _textOverlays.indexWhere((o) => o.id == overlay.id);
                                  if (idx != -1) {
                                    _textOverlays[idx] = updatedOverlay;
                                  }
                                });
                              }
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Brush Pen Selector Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildToolButton(CanvasTool.pencil, Icons.edit_outlined, 'Pencil'),
              _buildToolButton(CanvasTool.pen, Icons.brush_rounded, 'Pen'),
              _buildToolButton(CanvasTool.marker, Icons.border_color_rounded, 'Marker'),
              _buildToolButton(CanvasTool.bucket, Icons.format_color_fill_rounded, 'Bucket'),
              _buildToolButton(CanvasTool.eraser, Icons.cleaning_services_rounded, 'Eraser'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Color selection palette
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _paletteColors.length + 1,
            itemBuilder: (ctx, i) {
              if (i == _paletteColors.length) {
                // Custom color picker button
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _openCustomColorPicker(theme),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.textColor.withValues(alpha: 0.3), width: 1.5),
                        gradient: const SweepGradient(
                          colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.red],
                        ),
                      ),
                      child: Icon(Icons.add_rounded, color: theme.textColor, size: 20),
                    ),
                  ),
                );
              }

              final color = _paletteColors[i];
              final isSelected = _brushColor.toARGB32() == color.toARGB32();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _brushColor = color),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? theme.textColor : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Send Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_drawingLayerBase64 == null && _textOverlays.isEmpty && _pickedPhotoPath == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please create something on the canvas first! 🎨'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                
                final canvasData = CanvasData(
                  backgroundColor: _canvasBgColor.toARGB32(),
                  drawingLayer: _drawingLayerBase64,
                  textOverlays: _textOverlays,
                );
                
                provider.sendCanvas(jsonEncode(canvasData.toJson()), _pickedPhotoPath);
                _clearAllCanvas();
                _tabController.animateTo(1); // Switch to History
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Canvas sent to partner! 🚀'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded),
              label: Text(
                'Send to Partner',
                style: AppTypography.bodyLarge(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolButton(CanvasTool tool, IconData icon, String tooltip) {
    final theme = context.watch<ThemeProvider>().currentLoveTheme;
    final isSelected = _activeTool == tool;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTool = tool;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? theme.accentColor : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.transparent : theme.textColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : theme.textColor,
            size: 22,
          ),
        ),
      ),
    );
  }

  // 4. HISTORY LOG
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
              'No doodle notes exchanged yet.',
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
                  'Delete Note?',
                  style: AppTypography.sectionHeader(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(
                  'Are you sure you want to delete this shared note from history?',
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
                  'This love note couldn\'t be sent to your partner. Would you like to try sending it again?',
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
              width: 300,
              height: 300,
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
                        ? 'Sending Note...'
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
    if (CanvasData.isJson(item.content)) {
      try {
        final canvasData = CanvasData.fromJson(jsonDecode(item.content!));
        return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 600,
            height: 600,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Photo background if exists (either local imagePath or remote imageUrl)
                if (item.imagePath != null && File(item.imagePath!).existsSync())
                  Positioned.fill(
                    child: Image.file(File(item.imagePath!), fit: BoxFit.cover),
                  )
                else if (item.imageUrl != null)
                  Positioned.fill(
                    child: Image.network(item.imageUrl!, fit: BoxFit.cover),
                  ),
                
                // 2. Drawing layer if exists
                if (canvasData.drawingLayer != null && canvasData.drawingLayer!.isNotEmpty)
                  Positioned.fill(
                    child: Image.memory(
                      base64Decode(canvasData.drawingLayer!),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),

                // 3. Text overlays
                ...canvasData.textOverlays.map((overlay) {
                  final textStyle = AppTypography.lora(
                    fontSize: overlay.fontSize,
                    fontWeight: overlay.isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: overlay.isItalic ? FontStyle.italic : FontStyle.normal,
                    color: Color(overlay.color),
                  ).copyWith(
                    decoration: overlay.isUnderline ? TextDecoration.underline : TextDecoration.none,
                  );
                  
                  final alignment = overlay.alignment == 'left'
                      ? TextAlign.left
                      : overlay.alignment == 'right'
                          ? TextAlign.right
                          : TextAlign.center;
                  
                  return Positioned(
                    left: overlay.x,
                    top: overlay.y,
                    child: Transform.scale(
                      scale: overlay.scale,
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: overlay.backgroundColor == 0
                              ? Colors.transparent
                              : Color(overlay.backgroundColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(
                          overlay.text,
                          textAlign: alignment,
                          style: textStyle,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error parsing unified canvas json: $e');
      }
    }

    // Legacy Fallback Painter
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
    } else {
      // Photo
      if (item.imagePath != null && File(item.imagePath!).existsSync()) {
        return Image.file(
          File(item.imagePath!),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else if (item.imageUrl != null) {
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
      return Container(color: Colors.grey);
    }
  }
}
