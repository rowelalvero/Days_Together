import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/love_studio/time_capsule_controller.dart';

/// The bottom sheet for sealing a new time capsule -- a message and an
/// unlock date. Extracted from [TimeCapsuleScreen]'s
/// `_showCreateCapsuleSheet` (Migration audit item 6): a proper
/// `ConsumerStatefulWidget` with its own controller and date state, in
/// place of fields that used to live on `_TimeCapsuleScreenState` itself
/// (only ever read or written while this sheet was open) wrapped in a
/// `StatefulBuilder`.
///
/// Shown directly as a `showModalBottomSheet` builder, matching this app's
/// other sheets -- no `.show()` static helper.
class CreateTimeCapsuleSheet extends ConsumerStatefulWidget {
  const CreateTimeCapsuleSheet({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  ConsumerState<CreateTimeCapsuleSheet> createState() =>
      _CreateTimeCapsuleSheetState();
}

class _CreateTimeCapsuleSheetState
    extends ConsumerState<CreateTimeCapsuleSheet> {
  final TextEditingController _messageController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final theme = widget.theme;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now.add(const Duration(days: 1)),
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

  void _seal() {
    if (_messageController.text.trim().isEmpty || _selectedDate == null) {
      return;
    }
    ref
        .read(timeCapsuleControllerProvider.notifier)
        .createCapsule(_messageController.text.trim(), _selectedDate!);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔒 Time Capsule sealed and locked away!'),
        backgroundColor: Colors.pinkAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

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
                  '✉️ Create Time Capsule',
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
              controller: _messageController,
              style: AppTypography.body(color: theme.textColor),
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Write a letter, share a secret, or send a message to your future selves...\n\n"Dear future us..."',
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
            InkWell(
              onTap: () => _pickDate(context),
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
                    Text(
                      _selectedDate == null
                          ? 'Select Unlock Date'
                          : DateFormat('MMMM dd, yyyy').format(_selectedDate!),
                      style: AppTypography.body(
                        color: _selectedDate == null
                            ? theme.textColor.withValues(alpha: 0.4)
                            : theme.textColor,
                        fontSize: 16,
                      ),
                    ),
                    Icon(
                      Icons.calendar_today_rounded,
                      color: theme.textColor.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _seal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  'Seal Time Capsule',
                  style: AppTypography.button(
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
