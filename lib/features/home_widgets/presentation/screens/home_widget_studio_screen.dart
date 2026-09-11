import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/app/router/route_names.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/services/home_widget_service.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';
import 'package:days_together/features/home_widgets/presentation/controllers/home_widget_studio_controller.dart';
import 'package:days_together/features/home_widgets/presentation/components/atoms/widget_pin_button.dart';
import 'package:days_together/features/home_widgets/presentation/components/atoms/widget_size_badge.dart';
import 'package:days_together/features/home_widgets/presentation/components/molecules/widget_theme_picker.dart';
import 'package:days_together/features/home_widgets/presentation/components/molecules/widget_content_editor.dart';
import 'package:days_together/features/home_widgets/presentation/components/organisms/widget_live_preview_card.dart';

class HomeWidgetStudioScreen extends ConsumerWidget {
  const HomeWidgetStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studioState = ref.watch(homeWidgetStudioControllerProvider);
    final studioController = ref.read(homeWidgetStudioControllerProvider.notifier);
    final coupleSession = ref.watch(coupleSessionProvider);
    final profile = ref.watch(profileControllerProvider);

    final theme = ThemeManager.getTheme(studioState.config.themeType);
    final startDate = coupleSession.startDate ?? DateTime.now().subtract(const Duration(days: 1468));
    final partner1Name = profile.yourName ?? 'Ashley';
    final partner2Name = profile.partnerName ?? 'Rowel';

    final durationText = HomeWidgetService.formatDuration(
      startDate,
      format: studioState.config.counterFormat,
      showSeconds: studioState.config.showSeconds,
    );

    final totalSeconds = DateTime.now().difference(startDate).inSeconds;
    final daysCount = (totalSeconds ~/ 86400).toString();
    final hours = ((totalSeconds % 86400) ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final timeText = studioState.config.showSeconds ? '$hours:$minutes:$seconds' : '$hours:$minutes';

    return Scaffold(
      backgroundColor: const Color(0xFF070814),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Home Screen Widgets',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Widget Type / Size Selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    WidgetSizeBadge(
                      sizeLabel: 'NoteIt (2x2)',
                      isSelected: studioState.selectedWidgetType == HomeWidgetType.noteit2x2,
                      onTap: () => studioController.setWidgetType(HomeWidgetType.noteit2x2),
                    ),
                    const SizedBox(width: 8),
                    WidgetSizeBadge(
                      sizeLabel: 'Days Counter (2x2)',
                      isSelected: studioState.selectedWidgetType == HomeWidgetType.daysTogether2x2,
                      onTap: () => studioController.setWidgetType(HomeWidgetType.daysTogether2x2),
                    ),
                    const SizedBox(width: 8),
                    WidgetSizeBadge(
                      sizeLabel: 'Days Counter (4x2)',
                      isSelected: studioState.selectedWidgetType == HomeWidgetType.daysTogether4x2,
                      onTap: () => studioController.setWidgetType(HomeWidgetType.daysTogether4x2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Live Preview Mockup
              WidgetLivePreviewCard(
                widgetType: studioState.selectedWidgetType,
                config: studioState.config,
                theme: theme,
                partnerName: partner2Name,
                drawingContent: null,
                durationText: durationText,
                daysCount: daysCount,
                timeText: timeText,
                milestoneText: studioState.config.customMilestoneTag,
                partner1Name: partner1Name,
                partner2Name: partner2Name,
              ),
              const SizedBox(height: 24),

              // Theme Selector
              WidgetThemePicker(
                selectedTheme: studioState.config.themeType,
                onThemeChanged: (type) => studioController.setThemeType(type),
              ),
              const SizedBox(height: 20),

              // Content Form Editor
              WidgetContentEditor(
                widgetType: studioState.selectedWidgetType,
                config: studioState.config,
                onConfigChanged: (cfg) => studioController.updateConfig(cfg),
                onOpenNoteitCanvas: () => context.push(Routes.notes),
              ),
              const SizedBox(height: 24),

              // 1-Tap Add to Home Screen button
              WidgetPinButton(
                isLoading: studioState.isSyncing,
                label: 'Add to Home Screen',
                onPressed: () async {
                  await studioController.syncAllWidgets(
                    startDate: startDate,
                    partner1Name: partner1Name,
                    partner2Name: partner2Name,
                  );
                  final success = await studioController.pinCurrentWidget();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Widget pinned to home screen! 💖'
                              : 'Widgets synced! You can place them via your home screen launcher.',
                        ),
                        backgroundColor: const Color(0xFFE8477E),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),

              // Save & Force Sync button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    await studioController.syncAllWidgets(
                      startDate: startDate,
                      partner1Name: partner1Name,
                      partner2Name: partner2Name,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All widgets refreshed and synced with home screen! ✨'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('Save Changes & Force Sync'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Instructions Tile
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📱 Manual Installation Guide',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Android: Long-press your home screen launcher -> Tap "Widgets" -> Search "Days Together" -> Drag NoteIt or Days Counter to your screen.\n• iOS: Long-press on your home screen -> Tap the "+" icon at the top corner -> Search "Days Together" -> Select 2x2 or 4x2 widget size.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
