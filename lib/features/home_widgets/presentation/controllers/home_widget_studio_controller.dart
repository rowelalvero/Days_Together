import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:days_together/shared/models/app_settings.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/core/platform/home_widget/home_widget_service.dart';
import 'package:days_together/features/home_widgets/data/home_widget_repository.dart';
import 'package:days_together/core/platform/home_widget/home_widget_models.dart';

class HomeWidgetStudioState {
  final HomeWidgetType selectedWidgetType;
  final HomeWidgetConfig config;
  final bool isSyncing;
  final String? statusMessage;

  const HomeWidgetStudioState({
    this.selectedWidgetType = HomeWidgetType.noteit2x2,
    this.config = const HomeWidgetConfig(),
    this.isSyncing = false,
    this.statusMessage,
  });

  HomeWidgetStudioState copyWith({
    HomeWidgetType? selectedWidgetType,
    HomeWidgetConfig? config,
    bool? isSyncing,
    String? statusMessage,
  }) {
    return HomeWidgetStudioState(
      selectedWidgetType: selectedWidgetType ?? this.selectedWidgetType,
      config: config ?? this.config,
      isSyncing: isSyncing ?? this.isSyncing,
      statusMessage: statusMessage,
    );
  }
}

final homeWidgetStudioControllerProvider =
    NotifierProvider<HomeWidgetStudioNotifier, HomeWidgetStudioState>(
      HomeWidgetStudioNotifier.new,
    );

class HomeWidgetStudioNotifier extends Notifier<HomeWidgetStudioState> {
  late final HomeWidgetRepository _repository;

  @override
  HomeWidgetStudioState build() {
    _repository = ref.watch(homeWidgetRepositoryProvider);
    final savedConfig = _repository.loadConfig();
    return HomeWidgetStudioState(config: savedConfig);
  }

  void setWidgetType(HomeWidgetType type) {
    state = state.copyWith(selectedWidgetType: type);
  }

  void updateConfig(HomeWidgetConfig newConfig) {
    state = state.copyWith(config: newConfig);
    _repository.saveConfig(newConfig);
  }

  void setThemeType(ThemeType themeType) {
    final updated = state.config.copyWith(themeType: themeType);
    updateConfig(updated);
  }

  Future<void> syncAllWidgets({
    DateTime? startDate,
    String? partner1Name,
    String? partner2Name,
    String? latestDrawing,
  }) async {
    state = state.copyWith(
      isSyncing: true,
      statusMessage: 'Syncing widgets...',
    );
    try {
      final theme = ThemeManager.getTheme(state.config.themeType);

      // 1. Sync NoteIt widget
      await HomeWidgetService.instance.renderAndSyncNoteit(
        partnerName: partner2Name ?? 'Ashley',
        drawingContent: latestDrawing,
        theme: theme,
      );

      // 2. Sync Days Together widget
      await HomeWidgetService.instance.renderAndSyncDaysTogether(
        startDate: startDate,
        config: state.config,
        theme: theme,
        partner1Name: partner1Name ?? 'Ashley',
        partner2Name: partner2Name ?? 'Rowel',
        milestoneText: state.config.customMilestoneTag,
      );

      state = state.copyWith(
        isSyncing: false,
        statusMessage: 'Widgets updated successfully! ✨',
      );
    } catch (e) {
      state = state.copyWith(isSyncing: false, statusMessage: 'Sync error: $e');
    }
  }

  Future<bool> pinCurrentWidget() async {
    return await HomeWidgetService.instance.requestPin(
      state.selectedWidgetType,
    );
  }
}
