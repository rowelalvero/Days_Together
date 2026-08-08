import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/services/home_widget_service.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/services/relationship_lifecycle_manager.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (MethodCall methodCall) async => true,
    );
  });

  group('HomeWidgetService - Duration Calculation & Formatting Tests', () {
    test('1. Missing / null relationship date returns "0 Days 00:00:00"', () {
      final formatted = HomeWidgetService.formatDuration(null);
      expect(formatted, equals('0 Days 00:00:00'));
    });

    test('2. Start date in the future returns "0 Days 00:00:00"', () {
      final now = DateTime(2026, 8, 8, 12, 0, 0);
      final futureDate = DateTime(2026, 8, 9, 12, 0, 0);
      final formatted = HomeWidgetService.formatDuration(futureDate, now: now);
      expect(formatted, equals('0 Days 00:00:00'));
    });

    test('3. Zero-day relationship (same day, 05:03:09 elapsed)', () {
      final start = DateTime(2026, 8, 8, 0, 0, 0);
      final now = DateTime(2026, 8, 8, 5, 3, 9);
      final formatted = HomeWidgetService.formatDuration(start, now: now);
      expect(formatted, equals('0 Days 05:03:09'));
    });

    test('4. Single-day relationship with zero-padding check (1 Days 05:03:09)', () {
      final start = DateTime(2026, 8, 7, 0, 0, 0);
      final now = DateTime(2026, 8, 8, 5, 3, 9);
      final formatted = HomeWidgetService.formatDuration(start, now: now);
      expect(formatted, equals('1 Days 05:03:09'));
    });

    test('5. Hour, minute, second zero-padding for single digit numbers (00, 01, 09)', () {
      final start = DateTime(2026, 8, 8, 0, 0, 0);
      final now = DateTime(2026, 8, 8, 0, 1, 9);
      final formatted = HomeWidgetService.formatDuration(start, now: now);
      expect(formatted, equals('0 Days 00:01:09'));
    });

    test('6. Multiple-day relationship (25 Days 12:45:32)', () {
      final start = DateTime(2026, 7, 14, 0, 0, 0);
      final now = DateTime(2026, 8, 8, 12, 45, 32);
      final formatted = HomeWidgetService.formatDuration(start, now: now);
      expect(formatted, equals('25 Days 12:45:32'));
    });

    test('7. 100+ days relationship (100 Days 00:01:05)', () {
      final start = DateTime(2026, 4, 30, 0, 0, 0);
      final now = DateTime(2026, 8, 8, 0, 1, 5);
      final formatted = HomeWidgetService.formatDuration(start, now: now);
      expect(formatted, equals('100 Days 00:01:05'));
    });

    test('8. 1000+ days relationship (1468 Days 07:23:41)', () {
      final start = DateTime(2022, 8, 1, 0, 0, 0);
      final now = DateTime(2026, 8, 8, 7, 23, 41);
      final formatted = HomeWidgetService.formatDuration(start, now: now);
      expect(formatted, equals('1468 Days 07:23:41'));
    });

    test('9. Respects startTime when provided', () {
      final startDate = DateTime(2026, 8, 7);
      const startTime = TimeOfDay(hour: 10, minute: 30);
      final now = DateTime(2026, 8, 8, 12, 35, 15);
      final formatted = HomeWidgetService.formatDuration(
        startDate,
        startTime: startTime,
        now: now,
      );
      expect(formatted, equals('1 Days 02:05:15'));
    });
  });

  group('HomeWidgetService - Lifecycle & Relationship Integration Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('10. HomeWidgetService.clearWidget executes without throwing', () async {
      await expectLater(HomeWidgetService.instance.clearWidget(), completes);
    });

    test('11. HomeWidgetService.updateWidget with null startDate executes clearWidget safely', () async {
      await expectLater(
        HomeWidgetService.instance.updateWidget(startDate: null),
        completes,
      );
    });

    test('12. RelationshipLifecycleManager.handleLogout triggers clearWidget safely', () async {
      await expectLater(
        RelationshipLifecycleManager.instance.handleLogout(),
        completes,
      );
    });

    test('13. RelationshipLifecycleManager.handleDisconnect triggers clearWidget safely', () async {
      await expectLater(
        RelationshipLifecycleManager.instance.handleDisconnect(),
        completes,
      );
    });

    test('14. RelationshipProvider.setStartDate updates widget date without error', () async {
      final provider = RelationshipProvider();
      await expectLater(
        provider.setStartDate(DateTime(2023, 5, 20)),
        completes,
      );
      expect(provider.startDate, equals(DateTime(2023, 5, 20)));
    });
  });
}
