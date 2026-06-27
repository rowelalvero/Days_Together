import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/gift_reminder_provider.dart';
import 'package:days_together/models/gift_reminder_model.dart';
import 'package:days_together/themes/app_typography.dart';

class GiftRemindersScreen extends StatefulWidget {
  const GiftRemindersScreen({super.key});

  @override
  State<GiftRemindersScreen> createState() => _GiftRemindersScreenState();
}

class _GiftRemindersScreenState extends State<GiftRemindersScreen> {
  final TextEditingController _titleController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _showReminderSheet(BuildContext context, {GiftReminder? existingReminder}) {
    _titleController.text = existingReminder?.title ?? '';
    _selectedDate = existingReminder?.date;
    _selectedTime = existingReminder?.date != null ? TimeOfDay.fromDateTime(existingReminder!.date) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final themeProvider = context.watch<ThemeProvider>();
        final theme = themeProvider.currentLoveTheme;

        return StatefulBuilder(
          builder: (context, setModalState) {
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
                          existingReminder == null ? '🎁 New Gift Reminder' : '🎁 Edit Gift Reminder',
                          style: AppTypography.cardTitle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: theme.textColor.withValues(alpha: 0.7)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      style: AppTypography.body(color: theme.textColor),
                      decoration: InputDecoration(
                        hintText: 'e.g. Partner\'s Birthday, Valentine\'s Day',
                        hintStyle: AppTypography.body(color: theme.textColor.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: theme.textColor.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
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
                            onTap: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate ?? now,
                                firstDate: DateTime(now.year - 10),
                                lastDate: DateTime(now.year + 20),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.dark(
                                        primary: theme.accentColor,
                                        onPrimary: Colors.white,
                                        surface: theme.secondaryColor,
                                        onSurface: Colors.white,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setModalState(() {
                                  _selectedDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: theme.textColor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedDate == null
                                          ? 'Select Date'
                                          : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                                      style: AppTypography.body(
                                        color: _selectedDate == null
                                            ? theme.textColor.withValues(alpha: 0.4)
                                            : theme.textColor,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.calendar_today_rounded, size: 18, color: theme.textColor.withValues(alpha: 0.7)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _selectedTime ?? TimeOfDay.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.dark(
                                        primary: theme.accentColor,
                                        surface: theme.secondaryColor,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setModalState(() {
                                  _selectedTime = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: theme.textColor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
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
                                            ? theme.textColor.withValues(alpha: 0.4)
                                            : theme.textColor,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_selectedTime != null)
                                    GestureDetector(
                                      onTap: () => setModalState(() => _selectedTime = null),
                                      child: Icon(Icons.clear, size: 18, color: theme.textColor.withValues(alpha: 0.38)),
                                    )
                                  else
                                    Icon(Icons.access_time_rounded, size: 18, color: theme.textColor.withValues(alpha: 0.7)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_titleController.text.trim().isNotEmpty && _selectedDate != null) {
                            final combinedDate = DateTime(
                              _selectedDate!.year,
                              _selectedDate!.month,
                              _selectedDate!.day,
                              _selectedTime?.hour ?? 0,
                              _selectedTime?.minute ?? 0,
                            );

                            if (existingReminder == null) {
                              context.read<GiftReminderProvider>().addReminder(
                                    _titleController.text.trim(),
                                    combinedDate,
                                  );
                            } else {
                              context.read<GiftReminderProvider>().updateReminder(
                                    existingReminder.id,
                                    title: _titleController.text.trim(),
                                    date: combinedDate,
                                  );
                            }
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          existingReminder == null ? 'Add Reminder' : 'Update Reminder',
                          style: AppTypography.button(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final giftProvider = context.watch<GiftReminderProvider>();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: themeProvider.currentGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: giftProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : giftProvider.reminders.isEmpty
                          ? _buildEmptyState(theme)
                          : _buildListView(giftProvider, theme),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showReminderSheet(context),
        backgroundColor: theme.accentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentLoveTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gift Reminders',
                  style: AppTypography.cormorant(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  'Never forget a date. Prepare special surprises.',
                  style: AppTypography.spectral(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(GiftReminderProvider provider, dynamic theme) {
    final sortedList = provider.upcomingReminders;
    return ListView.builder(
      itemCount: sortedList.length,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
      itemBuilder: (context, index) {
        final reminder = sortedList[index];
        return _buildReminderCard(reminder, theme, provider);
      },
    );
  }

  Widget _buildReminderCard(GiftReminder reminder, dynamic theme, GiftReminderProvider provider) {
    final dateStr = DateFormat('MMMM dd').format(reminder.date);
    final daysLeft = reminder.daysUntil;
    String countdownStr;
    if (daysLeft == 0) {
      countdownStr = '🎉 TODAY!';
    } else if (daysLeft == 1) {
      countdownStr = '⏰ Tomorrow!';
    } else {
      countdownStr = '⏳ $daysLeft days left';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: reminder.isEnabled 
              ? theme.textColor.withValues(alpha: 0.1) 
              : theme.textColor.withValues(alpha: 0.03),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (reminder.isEnabled ? Colors.orangeAccent : Colors.grey)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '🎁',
                    style: AppTypography.body(
                      fontSize: 20,
                      color: reminder.isEnabled ? Colors.white : theme.textColor.withValues(alpha: 0.24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: AppTypography.body(
                          color: reminder.isEnabled ? theme.textColor : theme.textColor.withValues(alpha: 0.38),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ).copyWith(
                          decoration: reminder.isEnabled ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateStr${reminder.date.hour != 0 || reminder.date.minute != 0 ? ' at ${DateFormat.jm().format(reminder.date)}' : ''} (Next: ${DateFormat('MMMM dd, yyyy').format(reminder.nextOccurrence)})',
                        style: AppTypography.caption(
                          color: reminder.isEnabled ? theme.textColor.withValues(alpha: 0.6) : theme.textColor.withValues(alpha: 0.24),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: reminder.isEnabled,
                  activeTrackColor: theme.accentColor,
                  onChanged: (_) {
                    provider.toggleReminder(reminder.id);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: reminder.isEnabled
                        ? (daysLeft <= 14 ? Colors.redAccent : theme.accentColor).withValues(alpha: 0.15)
                        : theme.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    countdownStr,
                    style: AppTypography.caption(
                      color: reminder.isEnabled
                          ? (daysLeft <= 14 ? Colors.redAccent : theme.accentColor)
                          : theme.textColor.withValues(alpha: 0.3),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: theme.textColor.withValues(alpha: 0.38)),
                      onPressed: () => _showReminderSheet(context, existingReminder: reminder),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: theme.textColor.withValues(alpha: 0.38)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: theme.primaryColor,
                            title: Text('Delete Reminder?', style: AppTypography.cardTitle(color: theme.textColor)),
                            content: Text(
                              'Are you sure you want to delete this reminder?',
                              style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.7)),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel', style: AppTypography.button(color: theme.textColor.withValues(alpha: 0.7))),
                              ),
                              TextButton(
                                onPressed: () {
                                  provider.deleteReminder(reminder.id);
                                  Navigator.pop(context);
                                },
                                child: Text('Delete', style: AppTypography.button(color: theme.accentColor)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(dynamic theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.card_giftcard_outlined,
                size: 64,
                color: theme.accentColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Never forget a date.',
              style: AppTypography.pageTitle(
                color: theme.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add birthdays, anniversaries, or special surprise counters.',
              textAlign: TextAlign.center,
              style: AppTypography.spectral(
                color: theme.textColor.withValues(alpha: 0.5),
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
