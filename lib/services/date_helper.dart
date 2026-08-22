import 'package:flutter/material.dart' show TimeOfDay;
import 'package:intl/intl.dart';

/// A single upcoming relationship milestone (a round day-count or an
/// anniversary), as computed by [DateHelper.nextRelationshipMilestones].
class MilestoneInfo {
  final String title;
  final int daysUntil;
  final double progress; // 0.0 to 1.0

  const MilestoneInfo({
    required this.title,
    required this.daysUntil,
    required this.progress,
  });
}

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

  /// Calculates a person's current age in whole years from their birthdate,
  /// as of now. Returns null if [birthdate] is null.
  static int? calculateAge(DateTime? birthdate) {
    if (birthdate == null) return null;

    final today = DateTime.now();
    int age = today.year - birthdate.year;

    if (today.month < birthdate.month ||
        (today.month == birthdate.month && today.day < birthdate.day)) {
      age--;
    }

    return age;
  }

  /// Counts the number of Saturdays and Sundays in the inclusive date range
  /// [start, end] (both normalized to local midnight, matching calendar-day
  /// semantics). O(1) -- computed via full-week/remainder arithmetic rather
  /// than iterating day-by-day, which matters for a range spanning years.
  static int countWeekendDays(DateTime start, DateTime end) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    if (normalizedEnd.isBefore(normalizedStart)) return 0;

    final totalDays = normalizedEnd.difference(normalizedStart).inDays + 1; // inclusive
    final fullWeeks = totalDays ~/ 7;
    final remainder = totalDays % 7;

    int count = fullWeeks * 2; // each full week has exactly 1 Sat + 1 Sun
    var weekday = normalizedStart.weekday; // 1=Mon .. 7=Sun
    for (int i = 0; i < remainder; i++) {
      if (weekday == DateTime.saturday || weekday == DateTime.sunday) count++;
      weekday = weekday % 7 + 1;
    }
    return count;
  }

  /// Counts how many times [month]/[day] occurs within the inclusive range
  /// [start, end] -- e.g. how many Valentine's Days, birthdays, or
  /// anniversaries have occurred. Bounded by the number of years in the
  /// range (not the number of days), so a plain year loop is already O(1)
  /// in practice and is kept as-is rather than rewritten.
  static int countOccurrencesOfDate(
    DateTime start,
    DateTime end,
    int month,
    int day,
  ) {
    int count = 0;
    for (int y = start.year; y <= end.year; y++) {
      final d = DateTime(y, month, day);
      if ((d.isAfter(start) || d.isAtSameMomentAs(start)) &&
          (d.isBefore(end) || d.isAtSameMomentAs(end))) {
        count++;
      }
    }
    return count;
  }

  /// Short relative-time label used for compact list items: "Just now",
  /// "5m ago", "3h ago", "2d ago" (up to 7 days), then "MM/dd".
  static String formatRelativeTimeShort(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MM/dd').format(dateTime);
    }
  }

  /// Longer relative-time label used for activity feeds: fully-spelled-out
  /// "X minute(s)/hour(s) ago" for today, "Yesterday", then a locale-aware
  /// "MMM d, y" date for anything older.
  static String formatRelativeTimeLong(DateTime dateTime) {
    final now = DateTime.now();
    final localDateTime = dateTime.toLocal();
    final localNow = now.toLocal();

    // Check if same day
    final isSameDay =
        localDateTime.year == localNow.year &&
        localDateTime.month == localNow.month &&
        localDateTime.day == localNow.day;

    if (isSameDay) {
      final difference = localNow.difference(localDateTime);
      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        final mins = difference.inMinutes;
        return '$mins ${mins == 1 ? "minute" : "minutes"} ago';
      } else {
        final hours = difference.inHours;
        return '$hours ${hours == 1 ? "hour" : "hours"} ago';
      }
    }

    // Check if yesterday
    final yesterday = localNow.subtract(const Duration(days: 1));
    final isYesterday =
        localDateTime.year == yesterday.year &&
        localDateTime.month == yesterday.month &&
        localDateTime.day == yesterday.day;

    if (isYesterday) {
      return 'Yesterday';
    }

    // Formatted date for older entries (using locale)
    return DateFormat.yMMMd().format(localDateTime);
  }

  // ---- Relationship duration/milestone math (Phase 6b-3 of the
  // architecture migration) ----
  //
  // Extracted from the old RelationshipProvider (since deleted), where it
  // lived as a set of instance getters reading _startDate/_startTime
  // directly. ADR-009 called for this to become plain functions "during
  // Phase 5"; that never happened until now (Phase 6b-1's investigation
  // found it stranded and blocking RelationshipProvider's eventual
  // retirement, later completed in the Definition-of-Done sweep's item 4).
  // Every function below is a pure, parameterized equivalent of its
  // original getter, so any caller holding a couple's startDate/startTime
  // (WorkspaceController, now, rather than RelationshipProvider) can
  // compute the same values without depending on RelationshipProvider at
  // all.

  /// Combines a relationship's start date and start time into a single
  /// `DateTime`, defaulting the time-of-day to midnight when unset and the
  /// whole thing to "now" when there is no start date yet (matching
  /// RelationshipProvider's original `startDateTime` getter).
  static DateTime relationshipStartDateTime(DateTime? startDate, TimeOfDay? startTime) {
    if (startDate == null) return DateTime.now();
    return DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime?.hour ?? 0,
      startTime?.minute ?? 0,
    );
  }

  /// Calendar days elapsed since [startDate], or 0 if there is none yet.
  static int relationshipTotalDays(DateTime? startDate) {
    if (startDate == null) return 0;
    return calendarDaysBetween(startDate, DateTime.now());
  }

  /// Precise years/months/days/hours/minutes/seconds elapsed since
  /// [startDate]/[startTime], or all zeros if there is no start date yet.
  static Map<String, int> relationshipPreciseAge(DateTime? startDate, TimeOfDay? startTime) {
    if (startDate == null) {
      return {
        'years': 0,
        'months': 0,
        'days': 0,
        'hours': 0,
        'minutes': 0,
        'seconds': 0,
      };
    }
    return getPreciseAge(relationshipStartDateTime(startDate, startTime), DateTime.now());
  }

  /// Whole calendar months elapsed since [startDate], or 0 if there is none
  /// yet.
  static int relationshipTotalMonths(DateTime? startDate) {
    if (startDate == null) return 0;
    final now = DateTime.now();
    return (now.year - startDate.year) * 12 + now.month - startDate.month;
  }

  /// A human-readable "X Years, Y Months, Z Days" label, matching
  /// RelationshipProvider's original `relationshipAge` getter (always
  /// includes a days component, even if 0; years/months only when nonzero).
  static String relationshipAgeLabel(DateTime? startDate, TimeOfDay? startTime) {
    final age = relationshipPreciseAge(startDate, startTime);
    final parts = <String>[];
    if (age['years']! > 0) {
      parts.add("${age['years']} Year${age['years']! > 1 ? 's' : ''}");
    }
    if (age['months']! > 0) {
      parts.add("${age['months']} Month${age['months']! > 1 ? 's' : ''}");
    }
    parts.add("${age['days']} Day${age['days']! > 1 ? 's' : ''}");
    return parts.join(', ');
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  /// The next up to 5 upcoming milestones (round day-counts and
  /// anniversaries) for a relationship starting at [startDate]/[startTime],
  /// nearest first. Returns an empty list if there is no start date yet.
  static List<MilestoneInfo> nextRelationshipMilestones(DateTime? startDate, TimeOfDay? startTime) {
    if (startDate == null) return [];
    final milestones = <MilestoneInfo>[];
    final days = relationshipTotalDays(startDate);

    for (final target in [
      100,
      200,
      365,
      500,
      730,
      1000,
      1500,
      2000,
      2500,
      3000,
    ]) {
      if (days < target) {
        final daysUntil = target - days;
        int prev = 0;
        for (final p in [0, 100, 200, 365, 500, 730, 1000, 1500, 2000, 2500]) {
          if (p < target && p <= days) prev = p;
        }
        final progress = (days - prev) / (target - prev);
        String label;
        if (target == 365) {
          label = '1st Anniversary';
        } else if (target == 730) {
          label = '2nd Anniversary';
        } else {
          label = '$target Days';
        }
        milestones.add(
          MilestoneInfo(
            title: label,
            daysUntil: daysUntil,
            progress: progress.clamp(0.0, 1.0),
          ),
        );
        if (milestones.length >= 5) break;
      }
    }

    if (milestones.length < 5) {
      final years = relationshipPreciseAge(startDate, startTime)['years']!;
      final nextYear = years + 1;
      final anniversaryDate = getAnniversaryDate(startDate, nextYear);
      final daysUntilAnniversary = daysUntil(anniversaryDate);
      if (daysUntilAnniversary > 0) {
        final ordinal = _ordinal(nextYear);
        milestones.add(
          MilestoneInfo(
            title: '$ordinal Anniversary',
            daysUntil: daysUntilAnniversary,
            progress: 1.0 - (daysUntilAnniversary / 365.0).clamp(0.0, 1.0),
          ),
        );
      }
    }

    milestones.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return milestones.take(5).toList();
  }
}
