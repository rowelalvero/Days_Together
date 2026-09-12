import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/calendar/calendar_controller.dart';
import 'package:days_together/features/calendar/domain/entities/calendar_event_model.dart';
import 'package:days_together/features/theme/theme_controller.dart';

/// The bottom sheet for creating or editing a calendar event -- date, title,
/// description, type, and an optional time. Extracted from
/// [CalendarScreen]'s `_showEventSheet` (Migration audit item 6): a proper
/// `ConsumerStatefulWidget` with its own controllers and form fields, in
/// place of fields that used to live on `_CalendarScreenState` itself (only
/// ever read or written while this sheet was open) wrapped in a
/// `StatefulBuilder`.
///
/// Shown directly as a `showModalBottomSheet` builder, matching this app's
/// other sheets -- no `.show()` static helper.
class EventFormSheet extends ConsumerStatefulWidget {
  const EventFormSheet({super.key, this.existingEvent, this.initialDate});

  /// Null when creating a new event; the event being edited otherwise.
  final CalendarEvent? existingEvent;

  /// The day to default a new event to (the currently-selected day on the
  /// calendar). Ignored when [existingEvent] is set -- its own date wins.
  final DateTime? initialDate;

  @override
  ConsumerState<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends ConsumerState<EventFormSheet> {
  late final _titleController = TextEditingController(
    text: widget.existingEvent?.title ?? '',
  );
  late final _descController = TextEditingController(
    text: widget.existingEvent?.description ?? '',
  );
  late CalendarEventType _selectedType =
      widget.existingEvent?.type ?? CalendarEventType.other;
  late TimeOfDay? _selectedTime = widget.existingEvent?.time;
  late DateTime _eventDate =
      widget.existingEvent?.date ?? widget.initialDate ?? DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(
    String hint,
    Color accent,
    LoveStoryTheme theme,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body(
        color: theme.textColor.withValues(alpha: 0.3),
      ),
      filled: true,
      fillColor: theme.textColor.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: accent),
      ),
    );
  }

  String _eventTypeName(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.anniversary:
        return 'Anniversary';
      case CalendarEventType.birthday:
        return 'Birthday';
      case CalendarEventType.date:
        return 'Date';
      case CalendarEventType.travel:
        return 'Travel';
      case CalendarEventType.other:
        return 'Other';
    }
  }

  Future<void> _pickDate(LoveStoryTheme theme) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final isDark = theme.isDark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: theme.accentColor,
                    onPrimary: Colors.white,
                    surface: theme.secondaryColor,
                    onSurface: theme.textColor,
                  )
                : ColorScheme.light(
                    primary: theme.accentColor,
                    onPrimary: Colors.white,
                    surface: theme.primaryColor,
                    onSurface: theme.textColor,
                  ),
            dialogTheme: DialogThemeData(
              backgroundColor: isDark
                  ? theme.secondaryColor
                  : theme.primaryColor,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: isDark
                  ? theme.secondaryColor
                  : theme.primaryColor,
              headerForegroundColor: theme.textColor,
              weekdayStyle: TextStyle(
                color: theme.textColor.withValues(alpha: 0.7),
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return theme.textColor;
              }),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _pickTime(LoveStoryTheme theme) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        final isDark = theme.isDark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: theme.accentColor,
                    onPrimary: Colors.white,
                    surface: theme.secondaryColor,
                    onSurface: theme.textColor,
                  )
                : ColorScheme.light(
                    primary: theme.accentColor,
                    onPrimary: Colors.white,
                    surface: theme.primaryColor,
                    onSurface: theme.textColor,
                  ),
            dialogTheme: DialogThemeData(
              backgroundColor: isDark
                  ? theme.secondaryColor
                  : theme.primaryColor,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: isDark
                  ? theme.secondaryColor
                  : theme.primaryColor,
              hourMinuteTextColor: theme.textColor,
              hourMinuteColor: theme.textColor.withValues(alpha: 0.08),
              dayPeriodTextColor: theme.textColor,
              dayPeriodColor: theme.textColor.withValues(alpha: 0.08),
              dialTextColor: theme.textColor,
              dialBackgroundColor: theme.textColor.withValues(alpha: 0.08),
              dialHandColor: theme.accentColor,
              entryModeIconColor: theme.accentColor,
              helpTextStyle: TextStyle(
                color: theme.textColor.withValues(alpha: 0.7),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _delete() {
    final existing = widget.existingEvent;
    if (existing == null) return;
    ref.read(calendarControllerProvider.notifier).deleteEvent(existing.id);
    Navigator.pop(context);
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) return;
    final event = CalendarEvent(
      id: widget.existingEvent?.id,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      date: _eventDate,
      type: _selectedType,
      time: _selectedTime,
    );
    final notifier = ref.read(calendarControllerProvider.notifier);
    if (widget.existingEvent == null) {
      notifier.addEvent(event);
    } else {
      notifier.updateEvent(event);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeControllerProvider).currentLoveTheme;
    final existingEvent = widget.existingEvent;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.primaryColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  existingEvent == null ? '✨ New Event' : '📝 Edit Event',
                  style: AppTypography.display(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _pickDate(theme),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: theme.textColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Date: ${DateFormat('MMMM dd, yyyy').format(_eventDate)}',
                      style: AppTypography.body(color: theme.textColor),
                    ),
                    Icon(
                      Icons.calendar_today_rounded,
                      color: theme.textColor.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              style: AppTypography.body(color: theme.textColor),
              decoration: _inputDecoration(
                'Event Title (e.g. First Date)',
                theme.accentColor,
                theme,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 2,
              style: AppTypography.body(color: theme.textColor),
              decoration: _inputDecoration(
                'Description (optional)',
                theme.accentColor,
                theme,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Event Type',
              style: AppTypography.caption(
                color: theme.textColor.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 45,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: CalendarEventType.values.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final type = CalendarEventType.values[index];
                  final isSelected = _selectedType == type;
                  return ChoiceChip(
                    label: Text(_eventTypeName(type)),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedType = type),
                    selectedColor: theme.accentColor,
                    backgroundColor: theme.textColor.withValues(alpha: 0.05),
                    labelStyle: AppTypography.button(
                      color: isSelected
                          ? Colors.white
                          : theme.textColor.withValues(alpha: 0.7),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide.none,
                    showCheckmark: false,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _pickTime(theme),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: theme.textColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedTime == null
                          ? 'Set Time (Optional)'
                          : _selectedTime!.format(context),
                      style: AppTypography.body(
                        color: _selectedTime == null
                            ? theme.textColor.withValues(alpha: 0.3)
                            : theme.textColor,
                      ),
                    ),
                    Icon(
                      Icons.access_time_rounded,
                      color: theme.textColor.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (existingEvent != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OutlinedButton(
                        onPressed: _delete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text(
                      existingEvent == null ? 'Add Event' : 'Save Changes',
                      style: AppTypography.button(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
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
