import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/core/platform/home_widget/home_widget_constants.dart';
import 'package:days_together/core/platform/home_widget/home_widget_models.dart';

final homeWidgetRepositoryProvider = Provider<HomeWidgetRepository>((ref) {
  throw UnimplementedError(
    'homeWidgetRepositoryProvider must be initialized with SharedPreferences',
  );
});

class HomeWidgetRepository {
  final SharedPreferences _prefs;

  HomeWidgetRepository(this._prefs);

  HomeWidgetConfig loadConfig() {
    final raw = _prefs.getString(HomeWidgetConstants.keyWidgetConfigJson);
    if (raw == null || raw.isEmpty) {
      return const HomeWidgetConfig();
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return HomeWidgetConfig.fromJson(decoded);
    } catch (_) {
      return const HomeWidgetConfig();
    }
  }

  Future<void> saveConfig(HomeWidgetConfig config) async {
    final encoded = jsonEncode(config.toJson());
    await _prefs.setString(HomeWidgetConstants.keyWidgetConfigJson, encoded);
  }
}
