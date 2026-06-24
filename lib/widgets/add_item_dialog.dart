import 'dart:io';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:intl/intl.dart';

class AddItemDialog extends StatefulWidget {
  const AddItemDialog({super.key});

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  String? _imagePath;
  bool _isImageCard = true;
  bool _isSaving = false;
  String _selectedMood = '😍';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  final List<String> _moods = ['😍', '🥳', '😂', '😢', '🏠'];

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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPreview(theme),
                        const SizedBox(height: 24),
                        _buildDateTimeSection(theme),
                        const SizedBox(height: 24),
                        _buildToggleSection(theme),
                        const SizedBox(height: 32),
                        _buildMoodSelector(theme),
                        const SizedBox(height: 32),
                        _buildTextField('Title', _titleController, theme, hint: 'e.g., Our First Date'),
                        const SizedBox(height: 24),
                        _buildTextField('Where did it happen?', _locationController, theme, hint: 'e.g., Central Park, NYC'),
                        const SizedBox(height: 24),
                        _buildTextField('Description', _descriptionController, theme, hint: 'Write the story...', maxLines: 4),
                        const SizedBox(height: 32),
                        if (_isImageCard) _buildImageButton(theme),
                        const SizedBox(height: 96),
                      ],
                    ),
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
            'New Memory',
            style: AppTypography.pageTitle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: _isSaving ? null : _saveItem,
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(Icons.check_rounded, color: theme.accentColor, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(LoveStoryTheme theme) {
    return GlassContainer(
      height: 220,
      width: double.infinity,
      borderRadius: 28,
      padding: EdgeInsets.zero,
      child: _isImageCard ? _buildImagePreview(theme) : _buildTextPreview(theme),
    );
  }

  Widget _buildImagePreview(LoveStoryTheme theme) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: _imagePath != null && File(_imagePath!).existsSync()
                ? Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(image: FileImage(File(_imagePath!)), fit: BoxFit.cover),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    color: Colors.white.withValues(alpha: 0.05),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate_outlined, color: Colors.white30, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            'No photo selected',
                            style: AppTypography.bodyMedium(color: Colors.white30, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleController.text.isEmpty ? 'Title' : _titleController.text,
                  style: AppTypography.bodyLarge(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  _descriptionController.text.isEmpty ? 'Description...' : _descriptionController.text,
                  style: AppTypography.bodyMedium(color: Colors.white60, fontSize: 11),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextPreview(LoveStoryTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleController.text.isEmpty ? 'Title' : _titleController.text,
            style: AppTypography.bodyLarge(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            _descriptionController.text.isEmpty ? 'Your beautiful story goes here...' : _descriptionController.text,
            style: AppTypography.sectionHeader(color: Colors.white70, fontSize: 14, height: 1.5).copyWith(fontStyle: FontStyle.italic),
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeSection(LoveStoryTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WHEN DID IT HAPPEN?', style: AppTypography.bodyLarge(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold).copyWith(letterSpacing: 1.5)),
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
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: theme.accentColor,
                            onPrimary: Colors.white,
                            surface: theme.secondaryColor,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: GlassContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18, color: theme.accentColor),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: AppTypography.body(color: Colors.white, fontSize: 13),
                      ),
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
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: theme.accentColor,
                            onPrimary: Colors.white,
                            surface: theme.secondaryColor,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) setState(() => _selectedTime = picked);
                },
                child: GlassContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 18, color: theme.accentColor),
                      const SizedBox(width: 12),
                      Text(
                        _selectedTime.format(context),
                        style: AppTypography.body(color: Colors.white, fontSize: 13),
                      ),
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

  Widget _buildToggleSection(LoveStoryTheme theme) {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Include a Photo', style: AppTypography.bodyLarge(color: Colors.white, fontWeight: FontWeight.w600)),
          Switch.adaptive(
            value: _isImageCard,
            activeTrackColor: theme.accentColor,
            onChanged: (val) => setState(() => _isImageCard = val),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSelector(LoveStoryTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HOW DID IT FEEL?', style: AppTypography.bodyLarge(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold).copyWith(letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _moods.map((m) {
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

  Widget _buildTextField(String label, TextEditingController controller, LoveStoryTheme theme, {int maxLines = 1, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.bodyLarge(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold).copyWith(letterSpacing: 1.5)),
        const SizedBox(height: 12),
        GlassContainer(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: AppTypography.body(color: Colors.white),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageButton(LoveStoryTheme theme) {
    return ElevatedButton.icon(
      onPressed: _pickImage,
      icon: const Icon(Icons.add_photo_alternate_rounded),
      label: Text(_imagePath != null ? 'Change Photo' : 'Select Photo'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white10,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white24)),
        elevation: 0,
      ),
    );
  }

  Future<void> _pickImage() async {
    final path = await context.read<TimelineProvider>().pickImage(context);
    if (path != null) setState(() => _imagePath = path);
  }

  Future<void> _saveItem() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final combinedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final newItem = TimelineItemData(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        imagePath: _imagePath,
        date: combinedDate,
        isImageCard: _isImageCard,
        position: context.read<TimelineProvider>().timelineItems.length,
        mood: _selectedMood,
      );
      await context.read<TimelineProvider>().addTimelineItem(newItem);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }
}
