/// Whether [a] and [b] fall on the same calendar day, ignoring time of day.
///
/// Extracted from `CalendarScreen`'s private `_isSameDay` (Migration audit
/// item 6) so [CalendarMonthGrid] and [CalendarDayEventList] -- split out of
/// that same screen -- can share one copy instead of each carrying their own.
bool isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
