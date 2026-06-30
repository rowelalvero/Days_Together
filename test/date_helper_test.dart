import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/services/date_helper.dart';

void main() {
  group('DateHelper', () {
    test('isLeapYear correctly determines leap years', () {
      expect(DateHelper.isLeapYear(2024), isTrue); // Leap year
      expect(DateHelper.isLeapYear(2000), isTrue); // Century leap year
      expect(DateHelper.isLeapYear(1900), isFalse); // Century common year
      expect(DateHelper.isLeapYear(2023), isFalse); // Common year
    });

    test('getAnniversaryDate handles leap day rollover correctly', () {
      final leapStartDate = DateTime(2024, 2, 29);
      
      // 1 year offset target (2025 is not a leap year) -> should roll back to Feb 28
      final anniversary2025 = DateHelper.getAnniversaryDate(leapStartDate, 1);
      expect(anniversary2025.year, 2025);
      expect(anniversary2025.month, 2);
      expect(anniversary2025.day, 28);

      // 4 years offset target (2028 is a leap year) -> should preserve Feb 29
      final anniversary2028 = DateHelper.getAnniversaryDate(leapStartDate, 4);
      expect(anniversary2028.year, 2028);
      expect(anniversary2028.month, 2);
      expect(anniversary2028.day, 29);
    });

    test('calendarDaysBetween calculates days independent of DST or timezone shifts', () {
      // 1. Cross DST boundary (spring forward: e.g. March 10, 2024 in US)
      final startDST = DateTime(2024, 3, 9, 22, 0, 0);
      final endDST = DateTime(2024, 3, 11, 2, 0, 0);
      final diffDST = DateHelper.calendarDaysBetween(startDST, endDST);
      expect(diffDST, 2); // Difference in calendar days is exactly 2 days

      // 2. Simple comparison
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 1, 5);
      expect(DateHelper.calendarDaysBetween(start, end), 4);
      expect(DateHelper.calendarDaysBetween(end, start), -4);
    });

    test('getPreciseAge returns correct breakdowns', () {
      final start = DateTime(2020, 2, 29, 10, 30, 0);
      
      // 1. Exactly 4 years and a few hours later
      final target1 = DateTime(2024, 2, 29, 12, 45, 15);
      final age1 = DateHelper.getPreciseAge(start, target1);
      expect(age1['years'], 4);
      expect(age1['months'], 0);
      expect(age1['days'], 0);
      expect(age1['hours'], 2);
      expect(age1['minutes'], 15);
      expect(age1['seconds'], 15);

      // 2. Rollbacks: target date has lower day/month/time
      final target2 = DateTime(2024, 2, 28, 9, 20, 0);
      final age2 = DateHelper.getPreciseAge(start, target2);
      expect(age2['years'], 3); // rolled back because we haven't reached Feb 29 yet
      expect(age2['months'], 11);
      // Days will count from previous month (January has 31 days)
      expect(age2['days'], 29);
      expect(age2['hours'], 22);
      expect(age2['minutes'], 50);
      expect(age2['seconds'], 0);
    });
  });
}
