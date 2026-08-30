import 'package:flutter/material.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';
import 'package:days_together/features/home_widgets/presentation/components/molecules/widget_device_frame.dart';
import 'package:days_together/features/home_widgets/presentation/components/organisms/render_templates/noteit_2x2_render_card.dart';
import 'package:days_together/features/home_widgets/presentation/components/organisms/render_templates/days_together_2x2_render_card.dart';
import 'package:days_together/features/home_widgets/presentation/components/organisms/render_templates/days_together_4x2_render_card.dart';

class WidgetLivePreviewCard extends StatelessWidget {
  final HomeWidgetType widgetType;
  final HomeWidgetConfig config;
  final LoveStoryTheme theme;
  final String partnerName;
  final String? drawingContent;
  final String durationText;
  final String daysCount;
  final String timeText;
  final String? milestoneText;
  final String partner1Name;
  final String partner2Name;

  const WidgetLivePreviewCard({
    super.key,
    required this.widgetType,
    required this.config,
    required this.theme,
    required this.partnerName,
    this.drawingContent,
    required this.durationText,
    required this.daysCount,
    required this.timeText,
    this.milestoneText,
    required this.partner1Name,
    required this.partner2Name,
  });

  @override
  Widget build(BuildContext context) {
    Widget renderCard;

    switch (widgetType) {
      case HomeWidgetType.noteit2x2:
        renderCard = Noteit2x2RenderCard(
          theme: theme,
          partnerName: partnerName,
          drawingContent: drawingContent,
          timeAgo: 'Just now',
        );
        break;
      case HomeWidgetType.daysTogether2x2:
        renderCard = DaysTogether2x2RenderCard(
          theme: theme,
          config: config,
          durationText: durationText,
          milestoneText: milestoneText,
        );
        break;
      case HomeWidgetType.daysTogether4x2:
        renderCard = DaysTogether4x2RenderCard(
          theme: theme,
          config: config,
          daysCount: daysCount,
          timeText: timeText,
          milestoneText: milestoneText,
          partner1Name: partner1Name,
          partner2Name: partner2Name,
        );
        break;
    }

    return WidgetDeviceFrame(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: renderCard,
        ),
      ),
    );
  }
}
