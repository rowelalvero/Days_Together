import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/calendar_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/providers/gift_reminder_provider.dart';
import 'package:days_together/providers/vault_provider.dart';
import 'package:days_together/models/calendar_event_model.dart';
import 'package:days_together/models/vault_item_model.dart';
import 'package:days_together/screens/together/vault_screen.dart';
import 'package:days_together/screens/together/bucket_list_screen.dart';
import 'package:days_together/screens/together/gift_reminders_screen.dart';
import 'package:days_together/screens/love_story_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
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
    final eventDate = existingEvent?.date ?? initialDate ?? _selectedDay;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final themeProvider = context.watch<ThemeProvider>();
        final theme = themeProvider.currentLoveTheme;

        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF10122B),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                        existingEvent == null ? '✨ New Event' : '📝 Edit Event',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Date: ${DateFormat('MMMM dd, yyyy').format(eventDate)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Event Title (e.g. First Date)', theme.accentColor),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Description (optional)', theme.accentColor),
                  ),
                  const SizedBox(height: 16),
                  const Text('Event Type', style: TextStyle(color: Colors.white70, fontSize: 14)),
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
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide.none,
                          showCheckmark: false,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime ?? TimeOfDay.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: theme.accentColor,
                                surface: const Color(0xFF10122B),
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
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedTime == null ? 'Set Time (Optional)' : _selectedTime!.format(context),
                            style: TextStyle(
                              color: _selectedTime == null ? Colors.white30 : Colors.white,
                            ),
                          ),
                          const Icon(Icons.access_time_rounded, color: Colors.white70),
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
                                context.read<CalendarProvider>().deleteEvent(existingEvent.id);
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
                                context.read<CalendarProvider>().addEvent(event);
                              } else {
                                context.read<CalendarProvider>().updateEvent(event);
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
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

  InputDecoration _inputDecoration(String hint, Color accent) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final calendarProvider = context.watch<CalendarProvider>();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: themeProvider.currentGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildCalendar(theme, calendarProvider),
                const SizedBox(height: 20),
                Expanded(
                  child: _buildEventList(theme, calendarProvider),
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_focusedDay),
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(dynamic theme, CalendarProvider provider) {
    final relProvider = context.watch<RelationshipProvider>();
    final timelineProvider = context.watch<TimelineProvider>();
    final bucketProvider = context.watch<BucketListProvider>();
    final giftProvider = context.watch<GiftReminderProvider>();
    final vaultProvider = context.watch<VaultProvider>();

    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstDayOfWeek = firstDayOfMonth.weekday % 7; // Sunday = 0

    final weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((d) => Text(d, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold))).toList(),
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
            itemCount: 42, // 6 weeks
            itemBuilder: (context, index) {
              final dayNum = index - firstDayOfWeek + 1;
              if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();

              final date = DateTime(_focusedDay.year, _focusedDay.month, dayNum);
              final isSelected = _isSameDay(date, _selectedDay);
              final isToday = _isSameDay(date, DateTime.now());
              
              // Event checking
              final calendarEvents = provider.getEventsForDay(date);
              final hasTimeline = timelineProvider.timelineItems.any((i) => _isSameDay(i.date, date));
              final hasBucket = bucketProvider.items.any((i) => i.scheduledAt != null && _isSameDay(i.scheduledAt!, date));
              final hasGift = giftProvider.reminders.any((i) => _isSameDay(i.nextOccurrence, date));
              final hasVault = vaultProvider.allItems.any((i) => _isSameDay(i.createdAt, date));
              
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
                        style: TextStyle(
                          color: isSelected ? Colors.white : (isToday ? theme.accentColor : Colors.white70),
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

  Widget _buildEventList(dynamic theme, CalendarProvider provider) {
    final relProvider = context.watch<RelationshipProvider>();
    final timelineProvider = context.watch<TimelineProvider>();
    final bucketProvider = context.watch<BucketListProvider>();
    final giftProvider = context.watch<GiftReminderProvider>();
    final vaultProvider = context.watch<VaultProvider>();

    final events = provider.getEventsForDay(_selectedDay);
    
    // Check for other types
    final timelineItems = timelineProvider.timelineItems.where((i) => _isSameDay(i.date, _selectedDay)).toList();
    final bucketItems = bucketProvider.items.where((i) => i.scheduledAt != null && _isSameDay(i.scheduledAt!, _selectedDay)).toList();
    final giftItems = giftProvider.reminders.where((i) => _isSameDay(i.nextOccurrence, _selectedDay)).toList();
    final vaultItems = vaultProvider.allItems.where((i) => _isSameDay(i.createdAt, _selectedDay)).toList();

    // Check for anniversary
    final startDate = relProvider.startDate;
    final isAnniversary = startDate != null && 
        startDate.month == _selectedDay.month && 
        startDate.day == _selectedDay.day;

    final hasAny = events.isNotEmpty || isAnniversary || timelineItems.isNotEmpty || 
                  bucketItems.isNotEmpty || giftItems.isNotEmpty || vaultItems.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM dd, yyyy').format(_selectedDay),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          if (!hasAny)
            Expanded(
              child: Center(
                child: Text(
                  'No events for this day.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontStyle: FontStyle.italic),
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
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoveStoryScreen())),
                  )),
                  ...bucketItems.map((item) => _buildIntegratedCard(
                    title: item.title,
                    subtitle: 'Bucket List Goal${item.scheduledAt!.hour != 0 || item.scheduledAt!.minute != 0 ? ' • ${DateFormat.jm().format(item.scheduledAt!)}' : ''}',
                    emoji: '✅',
                    color: Colors.greenAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BucketListScreen())),
                  )),
                  ...giftItems.map((item) => _buildIntegratedCard(
                    title: item.title,
                    subtitle: 'Gift Reminder${item.date.hour != 0 || item.date.minute != 0 ? ' • ${DateFormat.jm().format(item.date)}' : ''}',
                    emoji: '🎁',
                    color: Colors.orangeAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GiftRemindersScreen())),
                  )),
                  ...vaultItems.map((item) => _buildIntegratedCard(
                    title: vaultProvider.isUnlocked ? (item.type == VaultItemType.letter ? 'Private Letter' : 'Private Photo') : 'Locked Memory',
                    subtitle: 'The Vault • ${DateFormat.jm().format(item.createdAt)}',
                    emoji: '🔒',
                    color: Colors.purpleAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen())),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
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
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Text(
                          subtitle,
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
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

  Widget _buildAnniversaryCard(dynamic theme, int years) {
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
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('💑', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  years == 0 ? 'The Day We Met' : '$years Year Anniversary',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'A very special day in our story.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event, dynamic theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
              child: Text(_getEventEmoji(event.type), style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  if (event.description?.isNotEmpty ?? false)
                    Text(
                      event.description!,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (event.time != null)
              Text(
                event.time!.format(context),
                style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Color _getEventColor(CalendarEventType type, dynamic theme) {
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
