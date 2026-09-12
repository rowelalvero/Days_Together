import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/calendar/calendar_controller.dart';
import 'package:days_together/features/calendar/domain/entities/calendar_event_model.dart';
import 'package:days_together/features/calendar/presentation/sheets/event_form_sheet.dart';
import 'package:days_together/features/calendar/presentation/widgets/calendar_day_event_list.dart';
import 'package:days_together/features/calendar/presentation/widgets/calendar_month_grid.dart';
import 'package:days_together/features/calendar/presentation/widgets/calendar_month_header.dart';

/// The Calendar feature's home screen: a month grid plus the selected day's
/// events, anniversary, and cross-feature reminders.
///
/// The month grid, the day's event list, their card renderers, and the
/// add/edit-event form were split out into their own widgets under
/// `presentation/widgets/` and `presentation/sheets/` (Migration audit item
/// 6) -- this class now owns only the two pieces of state a month view
/// genuinely needs: which month is focused, and which day is selected.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  void _showEventSheet(BuildContext context, {CalendarEvent? existingEvent}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EventFormSheet(
        existingEvent: existingEvent,
        initialDate: _selectedDay,
      ),
    );
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
                CalendarMonthHeader(
                  theme: theme,
                  focusedMonth: _focusedDay,
                  onBack: () => Navigator.pop(context),
                  onPreviousMonth: () => setState(
                    () => _focusedDay = DateTime(
                      _focusedDay.year,
                      _focusedDay.month - 1,
                    ),
                  ),
                  onNextMonth: () => setState(
                    () => _focusedDay = DateTime(
                      _focusedDay.year,
                      _focusedDay.month + 1,
                    ),
                  ),
                ),
                CalendarMonthGrid(
                  theme: theme,
                  calendar: calendarState,
                  focusedMonth: _focusedDay,
                  selectedDay: _selectedDay,
                  onDaySelected: (date) => setState(() => _selectedDay = date),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: CalendarDayEventList(
                    theme: theme,
                    calendar: calendarState,
                    selectedDay: _selectedDay,
                    onEditEvent: (event) =>
                        _showEventSheet(context, existingEvent: event),
                  ),
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
}
