import 'dart:io';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/widgets/comments_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';

import 'package:intl/intl.dart';

class TimelineItemWidget extends StatefulWidget {
  final TimelineItemData item;
  final int index;
  final bool isSelected;

  const TimelineItemWidget({
    super.key,
    required this.item,
    required this.index,
    this.isSelected = false,
  });

  @override
  State<TimelineItemWidget> createState() => _TimelineItemWidgetState();
}

class _TimelineItemWidgetState extends State<TimelineItemWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 400 + (widget.index % 5 * 100)),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    final bool isLeft = widget.index % 2 == 0;

    return FadeTransition(
      opacity: _animationController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic)),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: isLeft
                      ? Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _buildDetailContent(theme, CrossAxisAlignment.end),
                          ),
                        )
                      : _buildGlassCard(theme),
                ),
                _buildCenterPoint(theme),
                Expanded(
                  child: !isLeft
                      ? Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _buildDetailContent(theme, CrossAxisAlignment.start),
                          ),
                        )
                      : _buildGlassCard(theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetailContent(LoveStoryTheme theme, CrossAxisAlignment alignment) {
    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == CrossAxisAlignment.end) ...[
            Text(
              DateFormat('MMM dd, yyyy • h:mm a').format(widget.item.date),
              style: AppTypography.bodyLarge(fontSize: 11, color: theme.accentColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Icon(Icons.access_time_rounded, size: 12, color: theme.accentColor),
          ] else ...[
            Icon(Icons.access_time_rounded, size: 12, color: theme.accentColor),
            const SizedBox(width: 6),
            Text(
              DateFormat('MMM dd, yyyy • h:mm a').format(widget.item.date),
              style: AppTypography.bodyLarge(fontSize: 11, color: theme.accentColor, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
      if (widget.item.location != null && widget.item.location!.isNotEmpty) ...[
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alignment == CrossAxisAlignment.end) ...[
              Flexible(
                child: Text(
                  widget.item.location!,
                  style: AppTypography.bodyMedium(fontSize: 11, color: Colors.white70),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.location_on_rounded, size: 12, color: Colors.white70),
            ] else ...[
              const Icon(Icons.location_on_rounded, size: 12, color: Colors.white70),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.item.location!,
                  style: AppTypography.bodyMedium(fontSize: 11, color: Colors.white70),
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    ];
  }

  Widget _buildCenterPoint(dynamic theme) {
    final isSelected = widget.isSelected;
    return SizedBox(
      width: 40,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: isSelected ? 15.0 : 10.0,
          height: isSelected ? 15.0 : 10.0,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.accentColor.withValues(alpha: 0.8),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: theme.accentColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(LoveStoryTheme theme) {
    return OpenContainer(
      transitionType: ContainerTransitionType.fade,
      closedColor: Colors.transparent,
      openColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      closedBuilder: (context, action) => GestureDetector(
        onTap: action,
        child: GlassContainer(
          padding: const EdgeInsets.all(12),
          borderRadius: 24,
          opacity: 0.1,
          child: widget.item.isImageCard ? _buildImageContent(theme) : _buildTextContent(theme),
        ),
      ),
      openBuilder: (context, action) => MemoryDetailScreen(item: widget.item),
    );
  }

  Widget _buildImageContent(LoveStoryTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Image(
                image: _getImageProvider(widget.item),
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GlassContainer(
                  borderRadius: 12,
                  padding: const EdgeInsets.all(6),
                  blur: 5,
                  child: Text(widget.item.mood, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.item.title,
          style: AppTypography.bodyLarge(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          widget.item.description,
          style: AppTypography.bodyMedium(fontSize: 11, color: Colors.white60, height: 1.4),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTextContent(LoveStoryTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.item.title,
                style: AppTypography.bodyLarge(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.item.mood, style: const TextStyle(fontSize: 18)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.item.description,
          style: AppTypography.sectionHeader(fontSize: 13, color: Colors.white70, height: 1.5).copyWith(fontStyle: FontStyle.italic),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  ImageProvider _getImageProvider(TimelineItemData item) {
    final path = item.imagePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) return FileImage(file);
    }
    final url = item.networkImageUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return const AssetImage('assets/images/placeholder.jpg');
  }
}

class MemoryDetailScreen extends StatelessWidget {
  final TimelineItemData item;

  const MemoryDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final timelineProvider = context.watch<TimelineProvider>();
    final currentItem = timelineProvider.timelineItems.firstWhere(
      (i) => i.id == item.id,
      orElse: () => item,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: currentItem.imagePath != null || currentItem.networkImageUrl != null ? 350 : 120,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  leading: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.chat_bubble_outline_rounded, color: theme.accentColor, size: 24),
                      onPressed: () {
                        CommentsSidebar.show(context, currentItem);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_note_rounded, color: theme.accentColor, size: 28),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _EditItemDialog(item: currentItem),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: currentItem.imagePath != null || currentItem.networkImageUrl != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image(
                                image: _getImageProvider(currentItem),
                                fit: BoxFit.cover,
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentItem.title,
                                    style: AppTypography.pageTitle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 14, color: theme.accentColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        DateFormat('MMMM dd, yyyy').format(currentItem.date),
                                        style: AppTypography.body(color: Colors.white70, fontSize: 13),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(Icons.access_time_rounded, size: 14, color: theme.accentColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        DateFormat.jm().format(currentItem.date),
                                        style: AppTypography.body(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(currentItem.mood, style: const TextStyle(fontSize: 28)),
                            ),
                          ],
                        ),
                        if (currentItem.location != null && currentItem.location!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 16, color: Colors.white54),
                              const SizedBox(width: 6),
                              Text(
                                currentItem.location!,
                                style: AppTypography.body(color: Colors.white54, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 32),
                        GlassContainer(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          borderRadius: 30,
                          opacity: 0.08,
                          child: Text(
                            currentItem.description,
                            style: AppTypography.lora(
                              fontSize: 18,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.8,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => CommentsSidebar.show(context, currentItem),
                            child: GlassContainer(
                              borderRadius: 20,
                              opacity: 0.15,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 16, color: theme.accentColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${currentItem.comments.length}',
                                    style: AppTypography.bodyLarge(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'chats',
                                    style: AppTypography.bodyMedium(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider _getImageProvider(TimelineItemData item) {
    final path = item.imagePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) return FileImage(file);
    }
    final url = item.networkImageUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return const AssetImage('assets/images/placeholder.jpg');
  }
}

class _EditItemDialog extends StatefulWidget {
  final TimelineItemData item;

  const _EditItemDialog({required this.item});

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  String? _newImagePath;
  bool _isSaving = false;
  late String _selectedMood;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController = TextEditingController(text: widget.item.description);
    _locationController = TextEditingController(text: widget.item.location ?? '');
    _selectedMood = widget.item.mood;
    _selectedDate = widget.item.date;
    _selectedTime = TimeOfDay.fromDateTime(widget.item.date);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, theme),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageSection(theme),
                      const SizedBox(height: 32),
                      _buildDateTimeSection(theme),
                      const SizedBox(height: 32),
                      _buildMoodSelector(theme),
                      const SizedBox(height: 32),
                      _buildTextField('Title', _titleController, theme, maxLines: 1),
                      const SizedBox(height: 24),
                      _buildTextField('Where did it happen?', _locationController, theme, maxLines: 1),
                      const SizedBox(height: 24),
                      _buildTextField('Story', _descriptionController, theme, maxLines: 6),
                      const SizedBox(height: 40),
                      _buildDeleteButton(context, theme),
                      const SizedBox(height: 96),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, LoveStoryTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          ),
          Text(
            'Edit Memory',
            style: AppTypography.sectionHeader(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: _isSaving ? null : _saveChanges,
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(Icons.check_rounded, color: theme.accentColor, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(LoveStoryTheme theme) {
    return GestureDetector(
      onTap: _changeImage,
      child: GlassContainer(
        height: 200,
        width: double.infinity,
        borderRadius: 28,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image(
                  image: _getImageProvider(),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black26, Colors.black.withValues(alpha: 0.6)],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text('Change Photo', style: AppTypography.bodyLarge(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSection(LoveStoryTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DATE & TIME', style: AppTypography.bodyLarge(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold).copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: GlassContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: theme.accentColor),
                      const SizedBox(width: 8),
                      Text(DateFormat('MMM dd, yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                  );
                  if (picked != null) setState(() => _selectedTime = picked);
                },
                child: GlassContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 16, color: theme.accentColor),
                      const SizedBox(width: 8),
                      Text(_selectedTime.format(context), style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodSelector(LoveStoryTheme theme) {
    final moods = ['😍', '🥳', '😂', '😢', '🏠'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mood', style: AppTypography.bodyLarge(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold).copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: moods.map((m) {
            final isSelected = _selectedMood == m;
            return GestureDetector(
              onTap: () => setState(() => _selectedMood = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? theme.accentColor : Colors.white10,
                  shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                ),
                child: Text(m, style: const TextStyle(fontSize: 24)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, LoveStoryTheme theme, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.bodyLarge(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold).copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 12),
        GlassContainer(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: AppTypography.bodyLarge(color: Colors.white, fontSize: 16),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.white24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton(BuildContext context, LoveStoryTheme theme) {
    return Center(
      child: TextButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: theme.secondaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Delete Memory?', style: AppTypography.bodyLarge(color: Colors.white, fontWeight: FontWeight.bold)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Delete', style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            await context.read<TimelineProvider>().deleteTimelineItem(widget.item.id);
            if (context.mounted) {
              Navigator.pop(context); // Pop the Edit dialog
              Navigator.pop(context); // Pop the Detail screen
            }
          }
        },
        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
        label: Text('Delete Memory', style: AppTypography.bodyLarge(color: Colors.redAccent, fontWeight: FontWeight.bold)),
      ),
    );
  }

  ImageProvider _getImageProvider() {
    if (_newImagePath != null) {
      final file = File(_newImagePath!);
      if (file.existsSync()) return FileImage(file);
    }
    if (widget.item.imagePath != null && widget.item.imagePath!.isNotEmpty) {
      final file = File(widget.item.imagePath!);
      if (file.existsSync()) return FileImage(file);
    }
    if (widget.item.networkImageUrl != null && widget.item.networkImageUrl!.isNotEmpty) {
      return NetworkImage(widget.item.networkImageUrl!);
    }
    return const AssetImage('assets/images/placeholder.jpg');
  }

  Future<void> _changeImage() async {
    final path = await context.read<TimelineProvider>().pickImage(context);
    if (path != null) setState(() => _newImagePath = path);
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    final combinedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final updated = widget.item.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      imagePath: _newImagePath,
      mood: _selectedMood,
      date: combinedDate,
    );
    await context.read<TimelineProvider>().updateTimelineItem(widget.item.id, updated);
    if (mounted) Navigator.pop(context);
  }
}
