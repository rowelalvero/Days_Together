import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/calendar/calendar_controller.dart';
import 'package:days_together/features/calendar/calendar_state.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_controller.dart';
import 'package:days_together/features/vault/vault_controller.dart';
import 'package:days_together/models/calendar_event_model.dart';
import 'package:days_together/models/vault_item_model.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/themes/app_typography.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  CalendarEventType _selectedType = CalendarEventType.other;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showEventSheet(BuildContext context, {CalendarEvent? existingEvent, DateTime? initialDate}) {
    _titleController.text = existingEvent?.title ?? '';
    _descController.text = existingEvent?.description ?? '';
    _selectedType = existingEvent?.type ?? CalendarEventType.other;
    _selectedTime = existingEvent?.time;
    var eventDate = existingEvent?.date ?? initialDate ?? _selectedDay;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final themeState = ref.watch(themeControllerProvider);
        final theme = themeState.currentLoveTheme;

        return StatefulBuilder(builder: (context, setModalState) {
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
                        icon: Icon(Icons.close, color: theme.textColor.withValues(alpha: 0.7)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: eventDate,
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
                              dialogTheme: DialogThemeData(backgroundColor: isDark ? theme.secondaryColor : theme.primaryColor),
                              datePickerTheme: DatePickerThemeData(
                                backgroundColor: isDark ? theme.secondaryColor : theme.primaryColor,
                                headerForegroundColor: theme.textColor,
                                weekdayStyle: TextStyle(color: theme.textColor.withValues(alpha: 0.7)),
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
                      if (picked != null) setModalState(() => eventDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.textColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Date: ${DateFormat('MMMM dd, yyyy').format(eventDate)}',
                            style: AppTypography.body(color: theme.textColor),
                          ),
                          Icon(Icons.calendar_today_rounded, color: theme.textColor.withValues(alpha: 0.7)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    style: AppTypography.body(color: theme.textColor),
                    decoration: _inputDecoration('Event Title (e.g. First Date)', theme.accentColor, theme),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    style: AppTypography.body(color: theme.textColor),
                    decoration: _inputDecoration('Description (optional)', theme.accentColor, theme),
                  ),
                  const SizedBox(height: 16),
                  Text('Event Type', style: AppTypography.caption(color: theme.textColor.withValues(alpha: 0.7), fontSize: 14)),
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
                          label: Text(_getEventTypeName(type)),
                          selected: isSelected,
                          onSelected: (val) => setModalState(() => _selectedType = type),
                          selectedColor: theme.accentColor,
                          backgroundColor: theme.textColor.withValues(alpha: 0.05),
                          labelStyle: AppTypography.button(
                            color: isSelected ? Colors.white : theme.textColor.withValues(alpha: 0.7),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide.none,
                          showCheckmark: false,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
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
                              dialogTheme: DialogThemeData(backgroundColor: isDark ? theme.secondaryColor : theme.primaryColor),
                              timePickerTheme: TimePickerThemeData(
                                backgroundColor: isDark ? theme.secondaryColor : theme.primaryColor,
                                hourMinuteTextColor: theme.textColor,
                                hourMinuteColor: theme.textColor.withValues(alpha: 0.08),
                                dayPeriodTextColor: theme.textColor,
                                dayPeriodColor: theme.textColor.withValues(alpha: 0.08),
                                dialTextColor: theme.textColor,
                                dialBackgroundColor: theme.textColor.withValues(alpha: 0.08),
                                dialHandColor: theme.accentColor,
                                entryModeIconColor: theme.accentColor,
                                helpTextStyle: TextStyle(color: theme.textColor.withValues(alpha: 0.7)),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setModalState(() => _selectedTime = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.textColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedTime == null ? 'Set Time (Optional)' : _selectedTime!.format(context),
                            style: AppTypography.body(
                              color: _selectedTime == null ? theme.textColor.withValues(alpha: 0.3) : theme.textColor,
                            ),
                          ),
                          Icon(Icons.access_time_rounded, color: theme.textColor.withValues(alpha: 0.7)),
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
                              onPressed: () {
                                ref.read(calendarControllerProvider.notifier).deleteEvent(existingEvent.id);
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                padding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: const Text('Delete'),
                            ),
                          ),
                        ),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_titleController.text.trim().isNotEmpty) {
                              final event = CalendarEvent(
                                id: existingEvent?.id,
                                title: _titleController.text.trim(),
                                description: _descController.text.trim(),
                                date: eventDate,
                                type: _selectedType,
                                time: _selectedTime,
                              );
                              if (existingEvent == null) {
                                ref.read(calendarControllerProvider.notifier).addEvent(event);
                              } else {
                                ref.read(calendarControllerProvider.notifier).updateEvent(event);
                              }
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: Text(
                            existingEvent == null ? 'Add Event' : 'Save Changes',
                            style: AppTypography.button(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  InputDecoration _inputDecoration(String hint, Color accent, LoveStoryTheme theme) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body(color: theme.textColor.withValues(alpha: 0.3)),
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

  String _getEventTypeName(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.anniversary: return 'Anniversary';
      case CalendarEventType.birthday: return 'Birthday';
      case CalendarEventType.date: return 'Date';
      case CalendarEventType.travel: return 'Travel';
      case CalendarEventType.other: return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final theme = themeState.currentLoveTheme;
    final calendarState = ref.watch(calendarControllerProvider);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: themeState.currentGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildCalendar(theme, calendarState),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildEventList(theme, calendarState),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEventSheet(context),
        backgroundColor: theme.accentColor,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = ref.watch(themeControllerProvider).currentLoveTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_focusedDay),
            style: AppTypography.display(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: theme.textColor),
                onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1)),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: theme.textColor),
                onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(LoveStoryTheme theme, CalendarState calendar) {
    final relProvider = ref.watch(workspaceControllerProvider);
    final timelineProvider = ref.watch(timelineControllerProvider);
    final bucketProvider = ref.watch(bucketListControllerProvider);
    final giftProvider = ref.watch(giftReminderControllerProvider);
    final vaultProvider = ref.watch(vaultControllerProvider);

    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstDayOfWeek = firstDayOfMonth.weekday % 7; // Sunday = 0

    final weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((d) => Text(d, style: AppTypography.caption(color: theme.textColor.withValues(alpha: 0.38), fontSize: 12, fontWeight: FontWeight.bold))).toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: ((firstDayOfWeek + daysInMonth) / 7).ceil() * 7,
            itemBuilder: (context, index) {
              final dayNum = index - firstDayOfWeek + 1;
              if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();

              final date = DateTime(_focusedDay.year, _focusedDay.month, dayNum);
              final isSelected = _isSameDay(date, _selectedDay);
              final isToday = _isSameDay(date, DateTime.now());
              
              // Event checking
              final calendarEvents = calendar.eventsForDay(date);
              final hasTimeline = timelineProvider.items.any((i) => _isSameDay(i.date, date));
              final hasBucket = bucketProvider.items.any((i) => i.scheduledAt != null && _isSameDay(i.scheduledAt!, date));
              final hasGift = giftProvider.reminders.any((i) => _isSameDay(i.nextOccurrence, date));
              final hasVault = vaultProvider.visibleItems.any((i) => _isSameDay(i.createdAt, date));
              
              final startDate = relProvider.startDate;
              final isAnniversary = startDate != null && 
                  startDate.month == date.month && 
                  startDate.day == date.day;

              final hasAnyEvent = calendarEvents.isNotEmpty || isAnniversary || hasTimeline || hasBucket || hasGift || hasVault;

              return GestureDetector(
                onTap: () => setState(() => _selectedDay = date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? theme.accentColor : (isToday ? theme.accentColor.withValues(alpha: 0.2) : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: isToday && !isSelected ? Border.all(color: theme.accentColor.withValues(alpha: 0.5)) : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: AppTypography.body(
                          color: isSelected ? Colors.white : (isToday ? theme.accentColor : theme.textColor.withValues(alpha: 0.7)),
                          fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (hasAnyEvent && !isSelected)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isAnniversary ? Colors.pinkAccent : theme.accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(LoveStoryTheme theme, CalendarState calendar) {
    final relProvider = ref.watch(workspaceControllerProvider);
    final timelineProvider = ref.watch(timelineControllerProvider);
    final bucketProvider = ref.watch(bucketListControllerProvider);
    final giftProvider = ref.watch(giftReminderControllerProvider);
    final vaultProvider = ref.watch(vaultControllerProvider);

    final events = calendar.eventsForDay(_selectedDay);
    
    // Check for other types
    final timelineItems = timelineProvider.items.where((i) => _isSameDay(i.date, _selectedDay)).toList();
    final bucketItems = bucketProvider.items.where((i) => i.scheduledAt != null && _isSameDay(i.scheduledAt!, _selectedDay)).toList();
    final giftItems = giftProvider.reminders.where((i) => _isSameDay(i.nextOccurrence, _selectedDay)).toList();
    final vaultItems = vaultProvider.visibleItems.where((i) => _isSameDay(i.createdAt, _selectedDay)).toList();

    // Check for anniversary
    final startDate = relProvider.startDate;
    final isAnniversary = startDate != null && 
        startDate.month == _selectedDay.month && 
        startDate.day == _selectedDay.day;

    final hasAny = events.isNotEmpty || isAnniversary || timelineItems.isNotEmpty || 
                  bucketItems.isNotEmpty || giftItems.isNotEmpty || vaultItems.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM dd, yyyy').format(_selectedDay),
            style: AppTypography.heading(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          if (!hasAny)
            Expanded(
              child: Center(
                child: Text(
                  'No events for this day.',
                  style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.3)).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  if (isAnniversary)
                    _buildAnniversaryCard(theme, _selectedDay.year - startDate.year),
                  ...events.map((event) => _buildEventCard(event, theme)),
                  ...timelineItems.map((item) => _buildIntegratedCard(
                    title: item.title,
                    subtitle: 'Story Entry • ${DateFormat.jm().format(item.date)}${item.location != null ? ' • ${item.location}' : ''}',
                    emoji: '📖',
                    color: Colors.blueAccent,
                    // Was Navigator.push(... LoveStoryScreen()) -- pushed a
                    // second, redundant instance of the app's own shell on
                    // top of the stack, since CalendarScreen is already
                    // reached from inside it (ADR-007's confirmed duplicate-
                    // shell finding). context.go returns to the existing
                    // shell instead of stacking a new one.
                    onTap: () => context.go(Routes.home),
                  )),
                  ...bucketItems.map((item) => _buildIntegratedCard(
                    title: item.title,
                    subtitle: 'Bucket List Goal${item.scheduledAt!.hour != 0 || item.scheduledAt!.minute != 0 ? ' • ${DateFormat.jm().format(item.scheduledAt!)}' : ''}',
                    emoji: '✅',
                    color: Colors.greenAccent,
                    onTap: () => context.push(Routes.bucketList),
                  )),
                  ...giftItems.map((item) => _buildIntegratedCard(
                    title: item.title,
                    subtitle: 'Gift Reminder${item.date.hour != 0 || item.date.minute != 0 ? ' • ${DateFormat.jm().format(item.date)}' : ''}',
                    emoji: '🎁',
                    color: Colors.orangeAccent,
                    onTap: () => context.push(Routes.gifts),
                  )),
                  ...vaultItems.map((item) => _buildIntegratedCard(
                    title: vaultProvider.isUnlocked ? (item.type == VaultItemType.letter ? 'Private Letter' : 'Private Photo') : 'Locked Memory',
                    subtitle: 'The Vault • ${DateFormat.jm().format(item.createdAt)}',
                    emoji: '🔒',
                    color: Colors.purpleAccent,
                    onTap: () => context.push(Routes.vault),
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntegratedCard({
    required String title,
    required String subtitle,
    required String emoji,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = ref.watch(themeControllerProvider).currentLoveTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(emoji, style: AppTypography.body(fontSize: 18)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body(color: theme.textColor, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Text(
                          subtitle,
                          style: AppTypography.caption(color: theme.textColor.withValues(alpha: 0.6), fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 8, color: color.withValues(alpha: 0.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnniversaryCard(LoveStoryTheme theme, int years) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.accentColor.withValues(alpha: 0.3), theme.accentColor.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.textColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('💑', style: AppTypography.body(fontSize: 18)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  years == 0 ? 'The Day We Met' : '$years Year Anniversary',
                  style: AppTypography.body(color: theme.textColor, fontWeight: FontWeight.bold),
                ),
                Text(
                  'A very special day in our story.',
                  style: AppTypography.caption(color: theme.textColor.withValues(alpha: 0.6), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event, LoveStoryTheme theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: () => _showEventSheet(context, existingEvent: event),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getEventColor(event.type, theme).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_getEventEmoji(event.type), style: AppTypography.body(fontSize: 18)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.body(color: theme.textColor, fontWeight: FontWeight.bold),
                  ),
                  if (event.description?.isNotEmpty ?? false)
                    Text(
                      event.description!,
                      style: AppTypography.caption(color: theme.textColor.withValues(alpha: 0.6), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (event.time != null)
              Text(
                event.time!.format(context),
                style: AppTypography.caption(color: theme.accentColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Color _getEventColor(CalendarEventType type, LoveStoryTheme theme) {
    switch (type) {
      case CalendarEventType.anniversary: return Colors.pinkAccent;
      case CalendarEventType.birthday: return Colors.orangeAccent;
      case CalendarEventType.date: return Colors.redAccent;
      case CalendarEventType.travel: return Colors.lightBlueAccent;
      case CalendarEventType.other: return theme.accentColor;
    }
  }

  String _getEventEmoji(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.anniversary: return '💑';
      case CalendarEventType.birthday: return '🎂';
      case CalendarEventType.date: return '🌹';
      case CalendarEventType.travel: return '✈️';
      case CalendarEventType.other: return '✨';
    }
  }
}
