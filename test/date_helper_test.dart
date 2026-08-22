import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/services/date_helper.dart';

/// Brute-force reference matching the exact semantics of the O(days) loop
/// that used to live in relationship_duration_screen.dart's
/// _buildFunStatistics -- normalizes both endpoints to local midnight,
/// iterates day-by-day inclusive of both ends, counts Sat/Sun.
///
/// This function intentionally duplicates the original (deleted) algorithm.
/// Its only job is to prove DateHelper.countWeekendDays' closed-form
/// implementation produces identical output, before the app trusted the
/// closed form in production. See docs/architecture/migration-roadmap.md
/// (Phase 0).
int _bruteForceCountWeekendDays(DateTime start, DateTime end) {
  int count = 0;
  DateTime current = DateTime(start.year, start.month, start.day);
  final normalizedEnd = DateTime(end.year, end.month, end.day);
  while (current.isBefore(normalizedEnd) || current.isAtSameMomentAs(normalizedEnd)) {
    if (current.weekday == DateTime.saturday || current.weekday == DateTime.sunday) {
      count++;
    }
    current = current.add(const Duration(days: 1));
  }
  return count;
}

void main() {
  group('DateHelper.calculateAge', () {
    test('returns null for a null birthdate', () {
      expect(DateHelper.calculateAge(null), isNull);
    });

    test('subtracts one year before the birthday has occurred this year', () {
      final now = DateTime.now();
      // A birthdate on Dec 31 has "not yet happened" for every day of the
      // year except Dec 31 itself -- deterministic without depending on
      // today's actual date, unlike a fixed month/day comparison would be.
      final birthdate = DateTime(now.year - 25, 12, 31);
      final expectedAge = (now.month == 12 && now.day == 31) ? 25 : 24;
      expect(DateHelper.calculateAge(birthdate), expectedAge);
    });

    test('a birthday of today counts the full year', () {
      final now = DateTime.now();
      final exactlyNYearsAgo = DateTime(now.year - 40, now.month, now.day);
      expect(DateHelper.calculateAge(exactlyNYearsAgo), 40);
    });
  });

  group('DateHelper.countWeekendDays -- closed form vs. brute force', () {
    test('matches the original O(days) loop across a wide range of spans', () {
      final start = DateTime(2020, 1, 1);
      // Every span from 0 to ~1500 days (covers multi-year relationship
      // durations, including leap years 2020, 2024) starting from every day
      // of the week.
      for (int offset = 0; offset < 10; offset++) {
        final rangeStart = start.add(Duration(days: offset));
        for (int span in [0, 1, 2, 6, 7, 8, 13, 14, 29, 30, 100, 365, 366, 730, 1000, 1461]) {
          final end = rangeStart.add(Duration(days: span));
          final closedForm = DateHelper.countWeekendDays(rangeStart, end);
          final bruteForce = _bruteForceCountWeekendDays(rangeStart, end);
          expect(
            closedForm,
            bruteForce,
            reason: 'start=$rangeStart span=$span: closed form=$closedForm, brute force=$bruteForce',
          );
        }
      }
    });

    test('handles the same start and end date (0-day span)', () {
      final saturday = DateTime(2026, 8, 22); // confirmed Saturday
      expect(DateHelper.countWeekendDays(saturday, saturday), 1);
      final monday = DateTime(2026, 8, 24);
      expect(DateHelper.countWeekendDays(monday, monday), 0);
    });

    test('returns 0 when end is before start', () {
      final a = DateTime(2026, 1, 10);
      final b = DateTime(2026, 1, 1);
      expect(DateHelper.countWeekendDays(a, b), 0);
    });

    test('ignores time-of-day, matching calendar-day semantics', () {
      final start = DateTime(2026, 1, 1, 23, 59);
      final end = DateTime(2026, 1, 31, 0, 1);
      expect(
        DateHelper.countWeekendDays(start, end),
        _bruteForceCountWeekendDays(start, end),
      );
    });
  });

  group('DateHelper.countOccurrencesOfDate', () {
    test('counts Valentine\'s Days across a multi-year span', () {
      final start = DateTime(2022, 1, 1);
      final end = DateTime(2026, 12, 31);
      // Feb 14 occurs once in each of 2022, 2023, 2024, 2025, 2026 = 5 times.
      expect(DateHelper.countOccurrencesOfDate(start, end, 2, 14), 5);
    });

    test('excludes occurrences before start or after end', () {
      final start = DateTime(2023, 3, 1);
      final end = DateTime(2023, 11, 30);
      // Feb 14 and Dec 25 both fall outside [start, end] in 2023.
      expect(DateHelper.countOccurrencesOfDate(start, end, 2, 14), 0);
      expect(DateHelper.countOccurrencesOfDate(start, end, 12, 25), 0);
    });

    test('includes the boundary date itself', () {
      final start = DateTime(2023, 2, 14);
      final end = DateTime(2023, 2, 14);
      expect(DateHelper.countOccurrencesOfDate(start, end, 2, 14), 1);
    });
  });

  group('DateHelper.formatRelativeTimeShort', () {
    test('shows "Just now" under one minute', () {
      final now = DateTime.now().subtract(const Duration(seconds: 10));
      expect(DateHelper.formatRelativeTimeShort(now), 'Just now');
    });

    test('shows minutes, then hours, then days, then a date', () {
      final now = DateTime.now();
      expect(DateHelper.formatRelativeTimeShort(now.subtract(const Duration(minutes: 5))), '5m ago');
      expect(DateHelper.formatRelativeTimeShort(now.subtract(const Duration(hours: 3))), '3h ago');
      expect(DateHelper.formatRelativeTimeShort(now.subtract(const Duration(days: 2))), '2d ago');
    });
  });

  group('DateHelper.formatRelativeTimeLong', () {
    test('shows "Just now" then spelled-out minutes/hours today', () {
      final now = DateTime.now();
      expect(DateHelper.formatRelativeTimeLong(now.subtract(const Duration(seconds: 5))), 'Just now');
      expect(DateHelper.formatRelativeTimeLong(now.subtract(const Duration(minutes: 1))), '1 minute ago');
      expect(DateHelper.formatRelativeTimeLong(now.subtract(const Duration(minutes: 5))), '5 minutes ago');
      expect(DateHelper.formatRelativeTimeLong(now.subtract(const Duration(hours: 1))), '1 hour ago');
    });

    test('shows "Yesterday" for the previous calendar day', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(DateHelper.formatRelativeTimeLong(yesterday), 'Yesterday');
    });
  });

  // Phase 6b-3 of the architecture migration: this math used to live as
  // instance getters on RelationshipProvider, reading its own private
  // _startDate/_startTime fields. Extracted here as pure functions so any
  // caller with a couple's startDate/startTime (WorkspaceController, not
  // RelationshipProvider) can compute the same values without depending on
  // RelationshipProvider at all -- see migration-roadmap.md's Phase 6b-3.
  group('DateHelper relationship duration/milestone math', () {
    test('all functions return their "no start date yet" defaults when startDate is null', () {
      expect(DateHelper.relationshipTotalDays(null), 0);
      expect(DateHelper.relationshipTotalMonths(null), 0);
      expect(
        DateHelper.relationshipPreciseAge(null, null),
        {'years': 0, 'months': 0, 'days': 0, 'hours': 0, 'minutes': 0, 'seconds': 0},
      );
      expect(DateHelper.nextRelationshipMilestones(null, null), isEmpty);
      // relationshipAgeLabel's days component only pluralizes above 1 (a
      // faithful match of the original getter's `> 1` check, not `!= 1`),
      // so an all-zero age renders "0 Day", singular.
      expect(DateHelper.relationshipAgeLabel(null, null), '0 Day');
    });

    test('relationshipStartDateTime combines date and time, defaulting time to midnight', () {
      final date = DateTime(2022, 6, 15);
      expect(
        DateHelper.relationshipStartDateTime(date, null),
        DateTime(2022, 6, 15, 0, 0),
      );
      expect(
        DateHelper.relationshipStartDateTime(date, const TimeOfDay(hour: 14, minute: 30)),
        DateTime(2022, 6, 15, 14, 30),
      );
    });

    test('relationshipStartDateTime returns "now" when there is no start date', () {
      final before = DateTime.now();
      final result = DateHelper.relationshipStartDateTime(null, null);
      final after = DateTime.now();
      expect(result.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('relationshipTotalDays matches calendarDaysBetween(startDate, now)', () {
      final startDate = DateTime.now().subtract(const Duration(days: 100));
      expect(
        DateHelper.relationshipTotalDays(startDate),
        DateHelper.calendarDaysBetween(startDate, DateTime.now()),
      );
    });

    test('relationshipPreciseAge matches getPreciseAge(relationshipStartDateTime(...), now)', () {
      final startDate = DateTime(2020, 1, 1);
      const startTime = TimeOfDay(hour: 9, minute: 0);
      final expected = DateHelper.getPreciseAge(
        DateHelper.relationshipStartDateTime(startDate, startTime),
        DateTime.now(),
      );
      expect(DateHelper.relationshipPreciseAge(startDate, startTime), expected);
    });

    test('relationshipTotalMonths counts whole calendar months elapsed', () {
      final now = DateTime.now();
      final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
      expect(DateHelper.relationshipTotalMonths(oneYearAgo), 12);
    });

    test('relationshipAgeLabel omits zero components except days, matching the original getter', () {
      // Exactly 0 years, 0 months elapsed (today) -> only a days component.
      final today = DateTime.now();
      final label = DateHelper.relationshipAgeLabel(DateTime(today.year, today.month, today.day), null);
      expect(label, matches(RegExp(r'^\d+ Days?$')));

      // A multi-year-old start date should include years and months.
      final threeYearsTwoMonthsAgo = DateTime(today.year - 3, today.month - 2, today.day);
      final multiPartLabel = DateHelper.relationshipAgeLabel(threeYearsTwoMonthsAgo, null);
      expect(multiPartLabel, contains('Year'));
      expect(multiPartLabel, contains('Month'));
    });

    test('nextRelationshipMilestones returns round day-count milestones nearest first', () {
      // 50 days in: the nearest round milestone is 100 days.
      final startDate = DateTime.now().subtract(const Duration(days: 50));
      final milestones = DateHelper.nextRelationshipMilestones(startDate, null);

      expect(milestones, isNotEmpty);
      expect(milestones.first.title, '100 Days');
      expect(milestones.first.daysUntil, 50);
      // Sorted nearest-first.
      for (var i = 1; i < milestones.length; i++) {
        expect(milestones[i].daysUntil, greaterThanOrEqualTo(milestones[i - 1].daysUntil));
      }
      expect(milestones.length, lessThanOrEqualTo(5));
    });

    test('nextRelationshipMilestones labels the 365-day and 730-day targets as anniversaries', () {
      final startDate = DateTime.now().subtract(const Duration(days: 300));
      final milestones = DateHelper.nextRelationshipMilestones(startDate, null);
      final anniversary = milestones.firstWhere((m) => m.daysUntil == 65);
      expect(anniversary.title, '1st Anniversary');
    });
  });
}
