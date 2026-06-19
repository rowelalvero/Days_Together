import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/noteit_provider.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/widgets/glass_container.dart';

class NoteitScreen extends StatefulWidget {
  const NoteitScreen({super.key});

  @override
  State<NoteitScreen> createState() => _NoteitScreenState();
}

class _NoteitScreenState extends State<NoteitScreen> with SingleTickerProviderStateMixin {
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

  // Widget Simulator state
  bool _showPartnerWidget = true; // true = show partner note to you, false = show your note to partner
  bool _paperAirplaneFlying = false;

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
    _tabController = TabController(length: 5, vsync: this);
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
        .map((stroke) => stroke.map((p) => '${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}').join(';'))
        .join('|');
  }

  Future<void> _pickImage(ImageSource source) async {
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

  void _triggerAirplaneAnimation() {
    setState(() {
      _paperAirplaneFlying = true;
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _paperAirplaneFlying = false;
        });
      }
    });
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
          'Love Notes',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textColor),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.accentColor,
          labelColor: theme.textColor,
          unselectedLabelColor: theme.textColor.withValues(alpha: 0.5),
          isScrollable: true,
          tabs: const [
            Tab(text: '📱 Widget'),
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
              _buildWidgetSimulator(theme, provider),
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

  // 1. WIDGET SIMULATOR
  Widget _buildWidgetSimulator(LoveStoryTheme theme, NoteitProvider provider) {
    final activeItem = _showPartnerWidget ? provider.latestReceived : provider.latestSent;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          // Widget configuration switch
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showPartnerWidget = true),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _showPartnerWidget ? theme.accentColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Received (Partner)',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: _showPartnerWidget ? Colors.white : theme.textColor.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showPartnerWidget = false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !_showPartnerWidget ? theme.accentColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Sent (You)',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: !_showPartnerWidget ? Colors.white : theme.textColor.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Visual Mockup Phone
          Stack(
            alignment: Alignment.center,
            children: [
              // Phone Outer Frame
              Container(
                width: 250,
                height: 470,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2F),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: Colors.grey.shade800, width: 8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      // Wallpaper
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF2C3E50), Color(0xFF000000)],
                          ),
                        ),
                      ),
                      // Stars Wallpaper effect
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MockStarsPainter(),
                        ),
                      ),

                      // Status Bar
                      Positioned(
                        top: 6,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '11:11',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Row(
                              children: [
                                Icon(Icons.wifi, color: Colors.white70, size: 10),
                                SizedBox(width: 4),
                                Icon(Icons.battery_5_bar_rounded, color: Colors.white70, size: 10),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Clock Widget
                      Positioned(
                        top: 36,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            Text(
                              '11:11 PM',
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              'Wednesday, June 17',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Love Notes Simulated Home Widget
                      Positioned(
                        top: 105,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.favorite_rounded,
                                    size: 10,
                                    color: theme.accentColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Love Notes Widget',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 180,
                              width: 210,
                              decoration: BoxDecoration(
                                color: activeItem != null && activeItem.backgroundColor != null
                                    ? activeItem.backgroundColor!.withValues(alpha: 0.95)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: activeItem == null
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            _showPartnerWidget
                                                ? 'Waiting for partner note... 😴'
                                                : 'No notes sent yet. Swipe to doodle!',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              color: Colors.white.withValues(alpha: 0.5),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      )
                                    : _buildWidgetContent(activeItem),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // App Icons row
                      Positioned(
                        bottom: 30,
                        left: 20,
                        right: 20,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMockAppIcon(Icons.phone_rounded, Colors.green),
                            _buildMockAppIcon(Icons.chat_bubble_rounded, Colors.blue),
                            _buildMockAppIcon(Icons.music_note_rounded, const Color(0xFF1DB954)),
                            _buildMockAppIcon(Icons.wb_sunny_rounded, Colors.orange),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Flying Paper Airplane Animation overlay
              if (_paperAirplaneFlying)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: -150.0, end: 350.0),
                  duration: const Duration(milliseconds: 1200),
                  builder: (context, val, child) {
                    double angle = -pi / 6;
                    double verticalVal = 180 + sin(val / 50) * 40;
                    return Positioned(
                      left: val,
                      top: verticalVal,
                      child: Transform.rotate(
                        angle: angle,
                        child: Icon(
                          Icons.send_rounded,
                          color: theme.accentColor,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 30),

          // Simulation Control Button
          GlassContainer(
            borderRadius: 20,
            opacity: 0.08,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                Text(
                  'Simulation Control',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Since this is a local device app, you can trigger a simulated incoming note from your partner to watch the widget update!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _triggerAirplaneAnimation();
                      Future.delayed(const Duration(milliseconds: 600), () {
                        provider.simulatePartnerResponse();
                        setState(() {
                          _showPartnerWidget = true; // Switch view to received widget
                        });
                      });
                    },
                    icon: const Icon(Icons.flight_takeoff_rounded),
                    label: const Text('Simulate Partner Response'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockAppIcon(IconData icon, Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildWidgetContent(NoteitItem item) {
    if (item.type == NoteitType.drawing) {
      return CustomPaint(
        painter: ScaleDrawingPainter(
          strokes: _deserializeStrokes(item.content),
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
          style: GoogleFonts.lora(
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
      if (item.imagePath != null) {
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
            return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
          },
        );
      }
      return Container(color: Colors.grey);
    }
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
                icon: Icon(Icons.delete_outline_rounded, color: theme.textColor),
                onPressed: _clearDoodle,
                tooltip: 'Clear canvas',
              ),
              const Spacer(),
              // Size selector indicator
              Text(
                'Size:',
                style: GoogleFonts.inter(color: theme.textColor.withValues(alpha: 0.6), fontSize: 12),
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
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1),
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
                  border: Border.all(color: theme.textColor.withValues(alpha: 0.15), width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15),
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
                style: GoogleFonts.inter(color: theme.textColor.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold),
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
                          color: isSel ? theme.accentColor : theme.textColor.withValues(alpha: 0.2),
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
                _tabController.animateTo(0); // Switch to widget tab
                _triggerAirplaneAnimation();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Doodle sent directly to widget! 🚀'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded),
              label: Text(
                'Send to Partner Widget',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            style: GoogleFonts.playfairDisplay(
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
              style: GoogleFonts.lora(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
              maxLength: 120,
              decoration: InputDecoration(
                hintText: 'Dear love, hope you have a beautiful day! ❤️',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
                counterStyle: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Card Color options
          Row(
            children: [
              Text(
                'CARD BG:',
                style: GoogleFonts.inter(
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
                          color: isSel ? theme.accentColor : theme.textColor.withValues(alpha: 0.2),
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
                _tabController.animateTo(0); // Go back to widget tab
                _triggerAirplaneAnimation();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sticky note sent directly to widget! 🚀'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded),
              label: Text(
                'Send Note to Partner',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            'Upload a Photo',
            style: GoogleFonts.playfairDisplay(
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
                              'Select a photo to send directly\nto your partner\'s screen.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: theme.textColor.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _pickImage(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library_outlined),
                                  label: const Text('Gallery'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.textColor,
                                    side: BorderSide(color: theme.textColor.withValues(alpha: 0.3)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () => _pickImage(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Camera'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.textColor,
                                    side: BorderSide(color: theme.textColor.withValues(alpha: 0.3)),
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
                            child: Image.file(
                              File(_pickedPhotoPath!),
                              fit: BoxFit.cover,
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
                                child: const Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                              onPressed: () => setState(() => _pickedPhotoPath = null),
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
                  _tabController.animateTo(0); // Switch to widget
                  _triggerAirplaneAnimation();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Photo sent directly to widget! 📸🚀'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  'Send Photo to Widget',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            Icon(Icons.history_toggle_off_rounded, size: 48, color: theme.textColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No love notes exchanged yet.',
              style: GoogleFonts.inter(color: theme.textColor.withValues(alpha: 0.5)),
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
                title: Text('Delete Note?', style: GoogleFonts.playfairDisplay(color: theme.textColor, fontWeight: FontWeight.bold)),
                content: Text('Are you sure you want to delete this shared note from history?', style: GoogleFonts.inter(color: theme.textColor.withValues(alpha: 0.8))),
                actions: [
                  TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
                  TextButton(
                    child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
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
              color: item.backgroundColor ?? Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.textColor.withValues(alpha: 0.1),
              ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.sender == 'you' ? 'Sent' : 'Received',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
                border: Border.all(color: Colors.white24, width: 2),
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
                item.sender == 'you' ? 'Sent by You' : 'Received from Partner',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
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

class ScaleDrawingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  ScaleDrawingPainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    bool hasPoints = false;

    for (final stroke in strokes) {
      for (final p in stroke) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
        hasPoints = true;
      }
    }

    if (!hasPoints) return;

    final w = maxX - minX;
    final h = maxY - minY;
    if (w == 0 || h == 0) return;

    const padding = 16.0;
    final targetW = size.width - 2 * padding;
    final targetH = size.height - 2 * padding;

    final scaleX = targetW / w;
    final scaleY = targetH / h;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final targetCenterX = size.width / 2;
    final targetCenterY = size.height / 2;
    final sourceCenterX = minX + w / 2;
    final sourceCenterY = minY + h / 2;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final firstPoint = stroke.first;
      final startX = targetCenterX + (firstPoint.dx - sourceCenterX) * scale;
      final startY = targetCenterY + (firstPoint.dy - sourceCenterY) * scale;

      final path = Path()..moveTo(startX, startY);
      for (int i = 1; i < stroke.length; i++) {
        final p = stroke[i];
        final px = targetCenterX + (p.dx - sourceCenterX) * scale;
        final py = targetCenterY + (p.dy - sourceCenterY) * scale;
        path.lineTo(px, py);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScaleDrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

List<List<Offset>> _deserializeStrokes(String? data) {
  if (data == null || data.isEmpty) return [];
  try {
    return data.split('|').map((strokeStr) {
      if (strokeStr.isEmpty) return <Offset>[];
      return strokeStr.split(';').map((pointStr) {
        final parts = pointStr.split(',');
        return Offset(double.parse(parts[0]), double.parse(parts[1]));
      }).toList();
    }).toList();
  } catch (e) {
    return [];
  }
}

class _MockStarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(42);
    final paint = Paint()..color = Colors.white70;
    for (int i = 0; i < 40; i++) {
      final dx = rand.nextDouble() * size.width;
      final dy = rand.nextDouble() * size.height;
      final r = rand.nextDouble() * 1.5;
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
