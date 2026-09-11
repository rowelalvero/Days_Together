import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/models/app_settings.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';
import 'package:days_together/features/home_widgets/presentation/components/organisms/render_templates/noteit_2x2_render_card.dart';
import 'package:days_together/features/home_widgets/presentation/components/organisms/render_templates/days_together_2x2_render_card.dart';
import 'package:days_together/features/home_widgets/presentation/components/organisms/render_templates/days_together_4x2_render_card.dart';

void main() {
  final theme = ThemeManager.getTheme(ThemeType.midnightRose);

  testWidgets('Noteit2x2RenderCard renders empty state and drawing state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Noteit2x2RenderCard(
            theme: theme,
            partnerName: 'Ashley',
            drawingContent: null,
          ),
        ),
      ),
    );
    expect(find.text('Ashley'), findsOneWidget);
    expect(find.text('Tap to draw first 💕'), findsOneWidget);
  });

  testWidgets('DaysTogether2x2RenderCard renders days count and title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DaysTogether2x2RenderCard(
            theme: theme,
            config: const HomeWidgetConfig(customTitle: 'Our Story'),
            durationText: '1,468 Days',
            milestoneText: '4th Anniversary',
          ),
        ),
      ),
    );
    expect(find.text('Our Story'), findsOneWidget);
    expect(find.text('1,468 Days'), findsOneWidget);
    expect(find.text('4th Anniversary'), findsOneWidget);
  });

  testWidgets('DaysTogether4x2RenderCard renders couple details and time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DaysTogether4x2RenderCard(
            theme: theme,
            config: const HomeWidgetConfig(customTitle: 'Ash & Wel'),
            daysCount: '1,468',
            timeText: '07:23:41',
            milestoneText: '4th Anniversary in 14d',
            partner1Name: 'Ashley',
            partner2Name: 'Rowel',
          ),
        ),
      ),
    );
    expect(find.text('Ash & Wel'), findsOneWidget);
    expect(find.text('1,468'), findsOneWidget);
    expect(find.text('07:23:41'), findsOneWidget);
  });
}
