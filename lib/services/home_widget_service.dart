import 'dart:io';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:days_together/models/app_settings.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_constants.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';
import 'package:days_together/features/home_widgets/presentation/components/organisms/render_templates/noteit_2x2_render_card.dart';
import 'package:days_together/features/home_widgets/presentation/components/organisms/render_templates/days_together_2x2_render_card.dart';
import 'package:days_together/features/home_widgets/presentation/components/organisms/render_templates/days_together_4x2_render_card.dart';

/// Dedicated service responsible for configuring, offscreen rendering,
/// and updating OS home screen widgets (`NoteIt` and `Days Together`).
class HomeWidgetService {
  HomeWidgetService._internal();
  static final HomeWidgetService instance = HomeWidgetService._internal();
  factory HomeWidgetService() => instance;

  static const String appGroupId = HomeWidgetConstants.appGroupId;
  static const String androidNoteitWidgetName = HomeWidgetConstants.androidNoteitWidgetName;
  static const String androidDaysTogetherWidgetName = HomeWidgetConstants.androidDaysTogetherWidgetName;
  static const String iOSNoteitWidgetName = HomeWidgetConstants.iOSNoteitWidgetName;
  static const String iOSDaysTogetherWidgetName = HomeWidgetConstants.iOSDaysTogetherWidgetName;

  static const String keyStartTimestamp = HomeWidgetConstants.keyStartTimestamp;
  static const String keyDurationText = HomeWidgetConstants.keyDurationText;
  static const String keyNoteitRenderPath = HomeWidgetConstants.keyNoteitRenderPath;
  static const String keyDaysTogetherRenderPath = HomeWidgetConstants.keyDaysTogetherRenderPath;

  /// Pure duration calculation and formatting function with format mode support.
  static String formatDuration(
    DateTime? startDate, {
    TimeOfDay? startTime,
    DateTime? now,
    DaysCounterFormat format = DaysCounterFormat.totalDays,
    bool showSeconds = true,
  }) {
    if (startDate == null) {
      return format == DaysCounterFormat.yearsMonthsDays
          ? '0 Yrs 0 Mos 0 Days'
          : '0 Days 00:00:00';
    }

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
      return format == DaysCounterFormat.yearsMonthsDays
          ? '0 Yrs 0 Mos 0 Days'
          : '0 Days 00:00:00';
    }

    final totalSeconds = difference.inSeconds;
    final totalDays = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    if (format == DaysCounterFormat.yearsMonthsDays) {
      int years = effectiveNow.year - startDateTime.year;
      int months = effectiveNow.month - startDateTime.month;
      int days = effectiveNow.day - startDateTime.day;

      if (days < 0) {
        months -= 1;
        final previousMonth = DateTime(effectiveNow.year, effectiveNow.month, 0);
        days += previousMonth.day;
      }
      if (months < 0) {
        years -= 1;
        months += 12;
      }
      if (years < 0) years = 0;
      if (months < 0) months = 0;
      if (days < 0) days = 0;

      return '$years Yrs $months Mos $days Days';
    } else if (format == DaysCounterFormat.compact) {
      return '$totalDays Days';
    } else {
      if (showSeconds) {
        return '$totalDays Days $hh:$mm:$ss';
      } else {
        return '$totalDays Days $hh:$mm';
      }
    }
  }

  /// Initialize HomeWidget iOS App Group configuration.
  Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (e, st) {
      debugPrint('HomeWidgetService.initialize error: $e\n$st');
    }
  }

  /// Offscreen render and sync partner NoteIt live drawing widget (2x2).
  Future<void> renderAndSyncNoteit({
    required String partnerName,
    String? drawingContent,
    String? timeAgo,
    LoveStoryTheme? theme,
  }) async {
    try {
      final effectiveTheme = theme ?? ThemeManager.getTheme(ThemeType.midnightRose);
      final widget = Noteit2x2RenderCard(
        theme: effectiveTheme,
        partnerName: partnerName,
        drawingContent: drawingContent,
        timeAgo: timeAgo,
      );

      final path = await HomeWidget.renderFlutterWidget(
        widget,
        key: 'noteit_2x2_rendered',
        logicalSize: const Size(320, 320),
      );

      if (path != null) {
        await HomeWidget.saveWidgetData<String>(keyNoteitRenderPath, path);
      }

      await HomeWidget.updateWidget(
        name: androidNoteitWidgetName,
        androidName: androidNoteitWidgetName,
        iOSName: iOSNoteitWidgetName,
      );
    } catch (e, st) {
      debugPrint('HomeWidgetService.renderAndSyncNoteit error: $e\n$st');
    }
  }

  /// Offscreen render and sync Days Together widget (2x2 & 4x2).
  Future<void> renderAndSyncDaysTogether({
    DateTime? startDate,
    TimeOfDay? startTime,
    HomeWidgetConfig? config,
    LoveStoryTheme? theme,
    String? partner1Name,
    String? partner2Name,
    String? milestoneText,
  }) async {
    try {
      if (startDate == null) {
        await clearWidget();
        return;
      }

      final effectiveConfig = config ?? const HomeWidgetConfig();
      final effectiveTheme = theme ?? ThemeManager.getTheme(effectiveConfig.themeType);

      final startDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        startTime?.hour ?? 0,
        startTime?.minute ?? 0,
      );

      final isoString = startDateTime.toIso8601String();
      final durationText = formatDuration(
        startDate,
        startTime: startTime,
        format: effectiveConfig.counterFormat,
        showSeconds: effectiveConfig.showSeconds,
      );

      final totalSeconds = DateTime.now().difference(startDateTime).inSeconds;
      final daysCount = (totalSeconds ~/ 86400).toString();
      final hours = ((totalSeconds % 86400) ~/ 3600).toString().padLeft(2, '0');
      final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
      final timeText = effectiveConfig.showSeconds ? '$hours:$minutes:$seconds' : '$hours:$minutes';

      // 1. Render 2x2 Days Together Card
      final card2x2 = DaysTogether2x2RenderCard(
        theme: effectiveTheme,
        config: effectiveConfig,
        durationText: durationText,
        milestoneText: milestoneText ?? effectiveConfig.customMilestoneTag,
      );

      // 2. Render 4x2 Days Together Card
      final card4x2 = DaysTogether4x2RenderCard(
        theme: effectiveTheme,
        config: effectiveConfig,
        daysCount: daysCount,
        timeText: timeText,
        milestoneText: milestoneText ?? effectiveConfig.customMilestoneTag,
        partner1Name: partner1Name ?? 'Ashley',
        partner2Name: partner2Name ?? 'Rowel',
      );

      final path2x2 = await HomeWidget.renderFlutterWidget(
        card2x2,
        key: 'days_together_2x2_rendered',
        logicalSize: const Size(320, 320),
      );

      await HomeWidget.renderFlutterWidget(
        card4x2,
        key: 'days_together_4x2_rendered',
        logicalSize: const Size(640, 320),
      );

      if (path2x2 != null) {
        await HomeWidget.saveWidgetData<String>(keyDaysTogetherRenderPath, path2x2);
      }
      await HomeWidget.saveWidgetData<String>(keyStartTimestamp, isoString);
      await HomeWidget.saveWidgetData<String>(keyDurationText, durationText);

      await HomeWidget.updateWidget(
        name: androidDaysTogetherWidgetName,
        androidName: androidDaysTogetherWidgetName,
        iOSName: iOSDaysTogetherWidgetName,
      );
    } catch (e, st) {
      debugPrint('HomeWidgetService.renderAndSyncDaysTogether error: $e\n$st');
    }
  }

  /// Request the operating system to pin the widget to home screen (Android).
  Future<bool> requestPin(HomeWidgetType type) async {
    try {
      if (Platform.isAndroid) {
        final widgetName = type == HomeWidgetType.noteit2x2
            ? androidNoteitWidgetName
            : androidDaysTogetherWidgetName;
        await HomeWidget.requestPinWidget(
          androidName: widgetName,
        );
        return true;
      }
      return false;
    } catch (e, st) {
      debugPrint('HomeWidgetService.requestPin error: $e\n$st');
      return false;
    }
  }

  /// Update home screen widget with the current relationship start date/time (legacy helper).
  Future<void> updateWidget({
    DateTime? startDate,
    TimeOfDay? startTime,
  }) async {
    await renderAndSyncDaysTogether(
      startDate: startDate,
      startTime: startTime,
    );
  }

  /// Clear home screen widget data upon logout or relationship disconnect.
  Future<void> clearWidget() async {
    try {
      await HomeWidget.saveWidgetData<String>(keyStartTimestamp, null);
      await HomeWidget.saveWidgetData<String>(keyDurationText, null);
      await HomeWidget.saveWidgetData<String>(keyNoteitRenderPath, null);
      await HomeWidget.saveWidgetData<String>(keyDaysTogetherRenderPath, null);

      await HomeWidget.updateWidget(
        name: androidDaysTogetherWidgetName,
        androidName: androidDaysTogetherWidgetName,
        iOSName: iOSDaysTogetherWidgetName,
      );
      await HomeWidget.updateWidget(
        name: androidNoteitWidgetName,
        androidName: androidNoteitWidgetName,
        iOSName: iOSNoteitWidgetName,
      );
    } catch (e, st) {
      debugPrint('HomeWidgetService.clearWidget error: $e\n$st');
    }
  }
}
