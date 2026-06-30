class DateHelper {
  /// Check if a year is a leap year.
  static bool isLeapYear(int year) {
    if (year % 4 != 0) return false;
    if (year % 100 != 0) return true;
    return year % 400 == 0;
  }

  /// Safely builds an anniversary date for a given year offset.
  /// Correctly handles the leap day (February 29) rollover to February 28 in non-leap years.
  static DateTime getAnniversaryDate(DateTime startDate, int yearOffset) {
    final targetYear = startDate.year + yearOffset;
    int month = startDate.month;
    int day = startDate.day;

    if (month == 2 && day == 29 && !isLeapYear(targetYear)) {
      day = 28; // Fallback for common February 29 anniversaries
    }

    return DateTime(targetYear, month, day);
  }

  /// Calculates the difference in full calendar days between two dates,
  /// bypassing any DST shifts or timezone changes.
  static int calendarDaysBetween(DateTime from, DateTime to) {
    // Normalize to midnight UTC to prevent local DST hour shifts from changing calculations
    final fromUtc = DateTime.utc(from.year, from.month, from.day);
    final toUtc = DateTime.utc(to.year, to.month, to.day);
    return toUtc.difference(fromUtc).inDays;
  }

  /// Calculates the exact number of calendar days remaining from today (local time)
  /// until the target date. Returns negative if the target date is in the past.
  static int daysUntil(DateTime targetDate) {
    final today = DateTime.now();
    return calendarDaysBetween(today, targetDate);
  }

  /// Computes precise difference in years, months, days, hours, minutes, and seconds
  /// between two dates, managing negative rollovers correctly.
  static Map<String, int> getPreciseAge(DateTime start, DateTime now) {
    int years = now.year - start.year;
    int months = now.month - start.month;
    int days = now.day - start.day;
    int hours = now.hour - start.hour;
    int minutes = now.minute - start.minute;
    int seconds = now.second - start.second;

    if (seconds < 0) {
      minutes--;
      seconds += 60;
    }
    if (minutes < 0) {
      hours--;
      minutes += 60;
    }
    if (hours < 0) {
      days--;
      hours += 24;
    }
    if (days < 0) {
      months--;
      // Get the number of days in the previous month of the current target year
      final previousMonth = DateTime(now.year, now.month, 0);
      days += previousMonth.day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }

    return {
      'years': years,
      'months': months,
      'days': days,
      'hours': hours,
      'minutes': minutes,
      'seconds': seconds,
    };
  }
}
