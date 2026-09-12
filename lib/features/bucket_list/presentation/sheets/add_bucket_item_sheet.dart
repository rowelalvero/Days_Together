import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/features/bucket_list/domain/entities/bucket_list_model.dart';
import 'package:days_together/features/theme/theme_controller.dart';

/// The bottom sheet for adding or editing a bucket-list adventure --
/// title, optional scheduled date/time. Extracted from
/// [BucketListScreen]'s `_showAddItemSheet` (Migration audit item 6): a
/// proper `ConsumerStatefulWidget` with its own controller and form state,
/// in place of fields that used to live on `_BucketListScreenState` itself
/// (only ever read or written while this sheet was open) wrapped in a
/// `StatefulBuilder`.
///
/// Shown directly as a `showModalBottomSheet` builder, matching this app's
/// other sheets -- no `.show()` static helper.
class AddBucketItemSheet extends ConsumerStatefulWidget {
  const AddBucketItemSheet({super.key, this.existingItem});

  /// Null when adding a new adventure; the item being edited otherwise.
  final BucketListItem? existingItem;

  @override
  ConsumerState<AddBucketItemSheet> createState() => _AddBucketItemSheetState();
}

class _AddBucketItemSheetState extends ConsumerState<AddBucketItemSheet> {
  late final _textController = TextEditingController(
    text: widget.existingItem?.title ?? '',
  );
  late DateTime? _selectedDate = widget.existingItem?.scheduledAt;
  late TimeOfDay? _selectedTime = widget.existingItem?.scheduledAt != null
      ? TimeOfDay.fromDateTime(widget.existingItem!.scheduledAt!)
      : null;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context, LoveStoryTheme theme) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 50),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: theme.accentColor,
              brightness: theme.isDark ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime(BuildContext context, LoveStoryTheme theme) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: theme.accentColor,
              brightness: theme.isDark ? Brightness.dark : Brightness.light,
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

  void _save() {
    if (_textController.text.trim().isEmpty) return;
    DateTime? scheduledAt;
    if (_selectedDate != null) {
      scheduledAt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime?.hour ?? 0,
        _selectedTime?.minute ?? 0,
      );
    }

    final existingItem = widget.existingItem;
    if (existingItem == null) {
      ref
          .read(bucketListControllerProvider.notifier)
          .addItem(_textController.text.trim(), scheduledAt: scheduledAt);
    } else {
      ref
          .read(bucketListControllerProvider.notifier)
          .updateItem(
            existingItem.id,
            title: _textController.text.trim(),
            scheduledAt: scheduledAt,
            clearDate: scheduledAt == null,
          );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final existingItem = widget.existingItem;
    final themeState = ref.watch(themeControllerProvider);
    final theme = themeState.currentLoveTheme;

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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  existingItem == null
                      ? '✨ Add New Adventure'
                      : '📝 Edit Adventure',
                  style: AppTypography.title(
                    fontSize: 20,
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
            TextField(
              controller: _textController,
              autofocus: true,
              style: AppTypography.body(color: theme.textColor),
              decoration: InputDecoration(
                hintText: 'e.g. Watch the sunset in Santorini 🌅',
                hintStyle: AppTypography.body(
                  color: theme.textColor.withValues(alpha: 0.3),
                ),
                filled: true,
                fillColor: theme.textColor.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: theme.textColor.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: theme.accentColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(context, theme),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
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
                          Expanded(
                            child: Text(
                              _selectedDate == null
                                  ? 'Set a Date'
                                  : DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(_selectedDate!),
                              style: AppTypography.body(
                                color: _selectedDate == null
                                    ? theme.textColor.withValues(alpha: 0.3)
                                    : theme.textColor,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedDate != null)
                            GestureDetector(
                              onTap: () => setState(() {
                                _selectedDate = null;
                                _selectedTime = null;
                              }),
                              child: Icon(
                                Icons.clear,
                                size: 18,
                                color: theme.textColor.withValues(alpha: 0.38),
                              ),
                            )
                          else
                            Icon(
                              Icons.calendar_month,
                              size: 18,
                              color: theme.textColor.withValues(alpha: 0.7),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_selectedDate != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(context, theme),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
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
                            Expanded(
                              child: Text(
                                _selectedTime == null
                                    ? 'Set Time'
                                    : _selectedTime!.format(context),
                                style: AppTypography.body(
                                  color: _selectedTime == null
                                      ? theme.textColor.withValues(alpha: 0.3)
                                      : theme.textColor,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedTime != null)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedTime = null),
                                child: Icon(
                                  Icons.clear,
                                  size: 18,
                                  color: theme.textColor.withValues(
                                    alpha: 0.38,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                Icons.access_time_rounded,
                                size: 18,
                                color: theme.textColor.withValues(alpha: 0.7),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  existingItem == null ? 'Add to List' : 'Update Adventure',
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
      ),
    );
  }
}
