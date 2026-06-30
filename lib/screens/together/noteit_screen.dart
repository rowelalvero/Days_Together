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

class NoteitScreen extends StatefulWidget {
  const NoteitScreen({super.key});

  @override
  State<NoteitScreen> createState() => _NoteitScreenState();
}

class _NoteitScreenState extends State<NoteitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  // Doodle state
  final List<List<Offset>> _doodleStrokes = [];
  List<Offset> _currentStroke = [];
  Color _brushColor = const Color(0xFFFF4D6D);
  double _strokeWidth = 4.0;
  Color _doodleBgColor = const Color(0xFF0F0B1A);

  // Sticky Note state
  final _textController = TextEditingController();
  Color _stickyBgColor = const Color(0xFF590D22);

  // Photo state
  String? _pickedPhotoPath;

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

  final List<Color> _canvasBgColors = [
    const Color(0xFF0F0B1A), // midnight
    const Color(0xFF1B0C1E), // deep violet
    const Color(0xFF001220), // dark blue
    const Color(0xFF2B1B17), // sand dark
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _undoDoodle() {
    if (_doodleStrokes.isNotEmpty) {
      setState(() {
        _doodleStrokes.removeLast();
      });
    }
  }

  void _clearDoodle() {
    setState(() {
      _doodleStrokes.clear();
    });
  }

  String _serializeDoodle() {
    return _doodleStrokes
        .map(
          (stroke) => stroke
              .map(
                (p) => '${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}',
              )
              .join(';'),
        )
        .join('|');
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
          isScrollable: true,
          tabs: const [
            Tab(text: '🎨 Doodle'),
            Tab(text: '📝 Text Note'),
            Tab(text: '📸 Photo'),
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
              _buildDoodleCanvas(theme, provider),
              _buildStickyNoteEditor(theme, provider),
              _buildPhotoPicker(theme, provider),
              _buildHistoryLog(theme, provider),
            ],
          ),
        ),
      ),
    );
  }

  // 2. DOODLE CANVAS
  Widget _buildDoodleCanvas(LoveStoryTheme theme, NoteitProvider provider) {
    return Column(
      children: [
        // Palette & Brush controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.undo_rounded, color: theme.textColor),
                onPressed: _undoDoodle,
                tooltip: 'Undo last stroke',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.textColor,
                ),
                onPressed: _clearDoodle,
                tooltip: 'Clear canvas',
              ),
              const Spacer(),
              // Size selector indicator
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
                  max: 12.0,
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

        // Color selection pills
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _paletteColors.length,
            itemBuilder: (ctx, i) {
              final color = _paletteColors[i];
              final isSelected = _brushColor == color;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _brushColor = color),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? theme.textColor : Colors.transparent,
                        width: 2,
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

        // Drawing Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AspectRatio(
              aspectRatio: 1.0, // square aspect ratio widget canvas
              child: Container(
                decoration: BoxDecoration(
                  color: _doodleBgColor,
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
                  child: GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _currentStroke = [details.localPosition];
                        _doodleStrokes.add(_currentStroke);
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _currentStroke.add(details.localPosition);
                      });
                    },
                    onPanEnd: (details) {
                      _currentStroke = [];
                    },
                    child: CustomPaint(
                      painter: CustomDrawingPainter(
                        strokes: _doodleStrokes,
                        brushColor: _brushColor,
                        strokeWidth: _strokeWidth,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Background options & Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'BG:',
                style: AppTypography.bodyLarge(
                  color: theme.textColor.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              ..._canvasBgColors.map((bg) {
                final isSel = _doodleBgColor == bg;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _doodleBgColor = bg),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel
                              ? theme.accentColor
                              : theme.textColor.withValues(alpha: 0.2),
                          width: isSel ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Send Button
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_doodleStrokes.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please draw something first! 🎨'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                provider.sendDrawing(_serializeDoodle(), _doodleBgColor);
                _clearDoodle();
                _tabController.animateTo(3); // Switch to History tab
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Doodle sent to partner! 🚀'),
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

  // 3. STICKY NOTE EDITOR
  Widget _buildStickyNoteEditor(LoveStoryTheme theme, NoteitProvider provider) {
    final cardBgColors = [
      const Color(0xFF590D22), // deep red
      const Color(0xFF10002B), // purple
      const Color(0xFF03045E), // royal blue
      const Color(0xFF1B4332), // green
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Write Sticky Note',
            style: AppTypography.sectionHeader(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 16),

          // Colored Card Text Box
          Container(
            height: 180,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _stickyBgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.textColor.withValues(alpha: 0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: TextField(
              controller: _textController,
              maxLines: 6,
              style: AppTypography.lora(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
              maxLength: 120,
              decoration: InputDecoration(
                hintText: 'Dear love, hope you have a beautiful day! ❤️',
                hintStyle: AppTypography.lora(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                ),
                border: InputBorder.none,
                counterStyle: AppTypography.caption(
                  color: Colors.white60,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Card Color options
          Row(
            children: [
              Text(
                'CARD BG:',
                style: AppTypography.bodyLarge(
                  color: theme.textColor.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              ...cardBgColors.map((bg) {
                final isSel = _stickyBgColor == bg;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _stickyBgColor = bg),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel
                              ? theme.accentColor
                              : theme.textColor.withValues(alpha: 0.2),
                          width: isSel ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 36),

          // Send Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_textController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please write a message first! ✍️'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                provider.sendText(_textController.text.trim(), _stickyBgColor);
                _textController.clear();
                _tabController.animateTo(3); // Switch to History tab
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Note shared with your partner! 🚀'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded),
              label: Text(
                'Send Note',
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
        ],
      ),
    );
  }

  // 4. PHOTO PICKER
  Widget _buildPhotoPicker(LoveStoryTheme theme, NoteitProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share a Photo',
            style: AppTypography.sectionHeader(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.textColor.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _pickedPhotoPath == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 48,
                              color: theme.textColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Select a photo to share directly\nto your partner\'s screen.',
                              textAlign: TextAlign.center,
                              style: AppTypography.body(
                                fontSize: 13,
                                color: theme.textColor.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _pickImage(ImageSource.gallery),
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: const Text('Gallery'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.textColor,
                                    side: BorderSide(
                                      color: theme.textColor.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _pickImage(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Camera'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.textColor,
                                    side: BorderSide(
                                      color: theme.textColor.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        children: [
                          Positioned.fill(
                            child:
                                _pickedPhotoPath != null &&
                                    File(_pickedPhotoPath!).existsSync()
                                ? Image.file(
                                    File(_pickedPhotoPath!),
                                    fit: BoxFit.cover,
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.image,
                                      color: Colors.white24,
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              onPressed: () =>
                                  setState(() => _pickedPhotoPath = null),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Send button
          if (_pickedPhotoPath != null)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  provider.sendPhoto(_pickedPhotoPath!);
                  setState(() {
                    _pickedPhotoPath = null;
                  });
                  _tabController.animateTo(3); // Switch to History tab
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Photo shared with your partner! 📸🚀'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  'Send Photo',
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
        ],
      ),
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
              color:
                  item.backgroundColor ?? theme.textColor.withValues(alpha: 0.05),
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
                color: item.backgroundColor ?? const Color(0xFF0F0B1A),
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

// ── CUSTOM CUSTOM PAINTERS ──

class CustomDrawingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color brushColor;
  final double strokeWidth;

  CustomDrawingPainter({
    required this.strokes,
    required this.brushColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = brushColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomDrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.brushColor != brushColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
