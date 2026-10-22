import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/timeline/presentation/widgets/edit_item_app_bar.dart';
import 'package:days_together/features/timeline/presentation/widgets/edit_item_date_time_section.dart';
import 'package:days_together/features/timeline/presentation/widgets/edit_item_delete_button.dart';
import 'package:days_together/features/timeline/presentation/widgets/edit_item_image_section.dart';
import 'package:days_together/features/timeline/presentation/widgets/edit_item_mood_selector.dart';
import 'package:days_together/features/timeline/presentation/widgets/edit_item_text_field.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/shared/models/timeline_model.dart';

/// The full-screen "edit this memory" dialog opened from
/// [MemoryDetailScreen]. Its `_buildX` methods were extracted into
/// `EditItem*` widgets under this same directory (Migration audit item 6)
/// -- this class still owns all the form state (text controllers, mood,
/// date/time, the freshly-picked image path) and the save/delete/pick
/// actions, matching how this app's other extracted forms keep state on
/// the screen/dialog's own State.
class EditItemDialog extends ConsumerStatefulWidget {
  final TimelineItemData item;

  const EditItemDialog({super.key, required this.item});

  @override
  ConsumerState<EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends ConsumerState<EditItemDialog> {
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
    _descriptionController = TextEditingController(
      text: widget.item.description,
    );
    _locationController = TextEditingController(
      text: widget.item.location ?? '',
    );
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
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: Column(
            children: [
              EditItemAppBar(
                theme: theme,
                isSaving: _isSaving,
                onSave: _saveChanges,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EditItemImageSection(
                        theme: theme,
                        networkImageUrl: widget.item.networkImageUrl,
                        localPath: _newImagePath ?? widget.item.imagePath,
                        onTap: _changeImage,
                      ),
                      const SizedBox(height: 32),
                      EditItemDateTimeSection(
                        theme: theme,
                        selectedDate: _selectedDate,
                        selectedTime: _selectedTime,
                        onDateTap: () => _pickDate(context),
                        onTimeTap: () => _pickTime(context),
                      ),
                      const SizedBox(height: 32),
                      EditItemMoodSelector(
                        theme: theme,
                        selectedMood: _selectedMood,
                        onMoodSelected: (m) =>
                            setState(() => _selectedMood = m),
                      ),
                      const SizedBox(height: 32),
                      EditItemTextField(
                        label: 'Title',
                        controller: _titleController,
                        theme: theme,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 24),
                      EditItemTextField(
                        label: 'Where did it happen?',
                        controller: _locationController,
                        theme: theme,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 24),
                      EditItemTextField(
                        label: 'Story',
                        controller: _descriptionController,
                        theme: theme,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 40),
                      EditItemDeleteButton(
                        theme: theme,
                        onConfirmedDelete: _confirmedDelete,
                      ),
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

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _confirmedDelete() async {
    await ref
        .read(timelineControllerProvider.notifier)
        .deleteTimelineItem(widget.item.id);
    if (mounted) {
      Navigator.pop(context); // Pop the Edit dialog
      Navigator.pop(context); // Pop the Detail screen
    }
  }

  Future<void> _changeImage() async {
    final path = await ref
        .read(timelineControllerProvider.notifier)
        .pickImage(context);
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
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      imagePath: _newImagePath,
      mood: _selectedMood,
      date: combinedDate,
    );
    await ref
        .read(timelineControllerProvider.notifier)
        .updateTimelineItem(widget.item.id, updated);
    if (mounted) Navigator.pop(context);
  }
}
