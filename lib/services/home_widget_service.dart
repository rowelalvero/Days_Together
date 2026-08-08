import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

/// Dedicated service responsible for configuring and updating the
/// home-screen relationship duration widget (`[DD] Days HH:MM:SS`).
class HomeWidgetService {
  HomeWidgetService._internal();
  static final HomeWidgetService instance = HomeWidgetService._internal();
  factory HomeWidgetService() => instance;

  static const String appGroupId = 'group.com.szacheo.days_together';
  static const String androidWidgetName = 'DaysTogetherWidgetProvider';
  static const String iOSWidgetName = 'DaysTogetherWidget';

  static const String keyStartTimestamp = 'start_timestamp';
  static const String keyDurationText = 'duration_text';

  /// Pure duration calculation and formatting function.
  ///
  /// Output format: `[DD] Days HH:MM:SS` (e.g. `1468 Days 07:23:41`).
  /// - Hours, minutes, and seconds are always 2-digit zero-padded.
  /// - Days represents total elapsed days without conversion to months/years.
  /// - Returns `0 Days 00:00:00` if [startDate] is null or in the future.
  static String formatDuration(
    DateTime? startDate, {
    TimeOfDay? startTime,
    DateTime? now,
  }) {
    if (startDate == null) return '0 Days 00:00:00';

    final effectiveNow = now ?? DateTime.now();
    final startDateTime = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime?.hour ?? 0,
      startTime?.minute ?? 0,
    );

    final difference = effectiveNow.difference(startDateTime);
    if (difference.isNegative) {
      return '0 Days 00:00:00';
    }

    final totalSeconds = difference.inSeconds;
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    return '$days Days $hh:$mm:$ss';
  }

  /// Initialize HomeWidget iOS App Group configuration.
  Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (e, st) {
      debugPrint('HomeWidgetService.initialize error: $e\n$st');
    }
  }

  /// Update home screen widget with the current relationship start date/time.
  Future<void> updateWidget({
    DateTime? startDate,
    TimeOfDay? startTime,
  }) async {
    try {
      if (startDate == null) {
        await clearWidget();
        return;
      }

      final startDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        startTime?.hour ?? 0,
        startTime?.minute ?? 0,
      );

      final isoString = startDateTime.toIso8601String();
      final durationText = formatDuration(startDate, startTime: startTime);

      await HomeWidget.saveWidgetData<String>(keyStartTimestamp, isoString);
      await HomeWidget.saveWidgetData<String>(keyDurationText, durationText);

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (e, st) {
      debugPrint('HomeWidgetService.updateWidget error: $e\n$st');
    }
  }

  /// Clear home screen widget data upon logout or relationship disconnect.
  Future<void> clearWidget() async {
    try {
      await HomeWidget.saveWidgetData<String>(keyStartTimestamp, null);
      await HomeWidget.saveWidgetData<String>(keyDurationText, null);

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (e, st) {
      debugPrint('HomeWidgetService.clearWidget error: $e\n$st');
    }
  }
}
