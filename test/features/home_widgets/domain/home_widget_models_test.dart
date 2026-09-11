import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/shared/models/app_settings.dart';
import 'package:days_together/core/platform/home_widget/home_widget_models.dart';
import 'package:days_together/core/platform/home_widget/home_widget_constants.dart';

void main() {
  group('HomeWidgetConfig', () {
    test('default configuration has correct initial values', () {
      const config = HomeWidgetConfig();
      expect(config.themeType, ThemeType.midnightRose);
      expect(config.counterFormat, DaysCounterFormat.totalDays);
      expect(config.customTitle, 'Days Together');
      expect(config.customMilestoneTag, '4th Anniversary');
      expect(config.showSeconds, isTrue);
      expect(config.showMilestone, isTrue);
      expect(config.selectedDrawingId, isNull);
    });

    test('copyWith updates selected fields correctly', () {
      const config = HomeWidgetConfig();
      final updated = config.copyWith(
        themeType: ThemeType.pink,
        customTitle: 'Ash & Wel',
        counterFormat: DaysCounterFormat.yearsMonthsDays,
      );
      expect(updated.themeType, ThemeType.pink);
      expect(updated.customTitle, 'Ash & Wel');
      expect(updated.counterFormat, DaysCounterFormat.yearsMonthsDays);
      expect(updated.customMilestoneTag, '4th Anniversary');
    });

    test('toJson and fromJson preserves data integrity', () {
      const config = HomeWidgetConfig(
        themeType: ThemeType.deepPurple,
        counterFormat: DaysCounterFormat.compact,
        customTitle: 'Together in Love',
        customMilestoneTag: 'Year 5',
        selectedDrawingId: 'note_123',
        showSeconds: false,
        showMilestone: false,
      );
      final json = config.toJson();
      final deserialized = HomeWidgetConfig.fromJson(json);
      expect(deserialized.themeType, ThemeType.deepPurple);
      expect(deserialized.counterFormat, DaysCounterFormat.compact);
      expect(deserialized.customTitle, 'Together in Love');
      expect(deserialized.customMilestoneTag, 'Year 5');
      expect(deserialized.selectedDrawingId, 'note_123');
      expect(deserialized.showSeconds, isFalse);
      expect(deserialized.showMilestone, isFalse);
    });
  });

  group('HomeWidgetConstants', () {
    test('constants are properly defined', () {
      expect(HomeWidgetConstants.appGroupId, 'group.com.szacheo.days_together');
      expect(HomeWidgetConstants.noteitDeepLink, 'daystogether://noteit');
      expect(HomeWidgetConstants.durationDeepLink, 'daystogether://duration');
    });
  });
}
