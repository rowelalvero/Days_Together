import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/widgets/memory_notes_section.dart';
import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/widgets/storage_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';

import 'package:intl/intl.dart';

/// Shown while a memory's image is resolving, or when it has none.
const AssetImage _kTimelineFallbackImage =
    AssetImage('assets/images/app_icon.png');

class MemoryDetailScreen extends StatefulWidget {
  final TimelineItemData item;

  const MemoryDetailScreen({super.key, required this.item});

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToNotes() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final timelineProvider = context.watch<TimelineProvider>();
    final currentItem = timelineProvider.timelineItems.firstWhere(
      (i) => i.id == widget.item.id,
      orElse: () => widget.item,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  expandedHeight: currentItem.imagePath != null || currentItem.networkImageUrl != null ? 350 : 120,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  leading: IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.rate_review_outlined, color: theme.accentColor, size: 24),
                      tooltip: 'Notes',
                      onPressed: _scrollToNotes,
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_note_rounded, color: theme.accentColor, size: 28),
                      tooltip: 'Edit Memory',
                      onPressed: () {
                        // EditItemDialog stays a plain Navigator.push --
                        // it's a dialog (edits then closes), not a
                        // navigational destination, despite using
                        // Navigator.push instead of showDialog (ADR-007's
                        // scope only covers "distinct screens").
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditItemDialog(item: currentItem),
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
                              StorageImageBuilder(
                                bucket: StorageBuckets.timeline,
                                storageRef: currentItem.networkImageUrl,
                                localPath: currentItem.imagePath,
                                builder: (context, image) => Image(
                                  image: image ?? _kTimelineFallbackImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: theme.textColor.withValues(alpha: 0.1),
                                    child: Center(
                                      child: Icon(Icons.broken_image_rounded, color: theme.textColor.withValues(alpha: 0.2), size: 48),
                                    ),
                                  ),
                                ),
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
                                    style: AppTypography.display(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 14, color: theme.accentColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        DateFormat('MMMM dd, yyyy').format(currentItem.date),
                                        style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.7), fontSize: 13),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(Icons.access_time_rounded, size: 14, color: theme.accentColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        DateFormat.jm().format(currentItem.date),
                                        style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.7), fontSize: 13),
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
                              child: Text(currentItem.mood, style: AppTypography.body(fontSize: 28)),
                            ),
                          ],
                        ),
                        if (currentItem.location != null && currentItem.location!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded, size: 16, color: theme.textColor.withValues(alpha: 0.54)),
                              const SizedBox(width: 6),
                              Text(
                                currentItem.location!,
                                style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.54), fontSize: 14),
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
                              color: theme.textColor.withValues(alpha: 0.9),
                              height: 1.8,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        MemoryNotesSection(
                          item: currentItem,
                          scrollController: _scrollController,
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

}

class EditItemDialog extends StatefulWidget {
  final TimelineItemData item;

  const EditItemDialog({super.key, required this.item});

  @override
  State<EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<EditItemDialog> {
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
            icon: Icon(Icons.close_rounded, color: theme.textColor, size: 28),
          ),
          Text(
            'Edit Memory',
            style: AppTypography.heading(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.bold),
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
                child: StorageImageBuilder(
                  bucket: StorageBuckets.timeline,
                  storageRef: widget.item.networkImageUrl,
                  // A freshly picked image wins over whatever is stored.
                  localPath: _newImagePath ?? widget.item.imagePath,
                  builder: (context, image) => Image(
                    image: image ?? _kTimelineFallbackImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: theme.textColor.withValues(alpha: 0.1),
                      child: Center(
                        child: Icon(Icons.broken_image_rounded, color: theme.textColor.withValues(alpha: 0.2), size: 48),
                      ),
                    ),
                  ),
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
        Text('DATE & TIME', style: AppTypography.bodyLarge(color: theme.textColor.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold).copyWith(letterSpacing: 1.2)),
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
                      Text(DateFormat('MMM dd, yyyy').format(_selectedDate), style: AppTypography.body(color: theme.textColor, fontSize: 13)),
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
                      Text(_selectedTime.format(context), style: AppTypography.body(color: theme.textColor, fontSize: 13)),
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
        Text('Mood', style: AppTypography.bodyLarge(color: theme.textColor.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold).copyWith(letterSpacing: 1.2)),
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
                child: Text(m, style: AppTypography.body(fontSize: 24)),
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
        Text(label.toUpperCase(), style: AppTypography.bodyLarge(color: theme.textColor.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold).copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 12),
        GlassContainer(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: AppTypography.bodyLarge(color: theme.textColor, fontSize: 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintStyle: AppTypography.body(color: theme.textColor.withValues(alpha: 0.24)),
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
              title: Text('Delete Memory?', style: AppTypography.bodyLarge(color: theme.textColor, fontWeight: FontWeight.bold)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: AppTypography.button(color: theme.textColor.withValues(alpha: 0.54)))),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Delete', style: AppTypography.button(color: theme.accentColor, fontWeight: FontWeight.bold)),
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
