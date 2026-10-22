import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/core/storage/scoped_json_cache.dart';
import 'package:days_together/shared/models/timeline_model.dart';
import 'package:days_together/shared/models/app_settings.dart';

/// General local persistence for data that never touches Supabase: cached
/// timeline items (SharedPreferences), app settings (theme/music,
/// SharedPreferences), and locally-saved image files (path_provider).
///
/// Previously named `TimelineRepository` and located under `lib/repositories/`
/// despite having no Supabase dependency at all -- moved here as part of
/// architecture Phase 0 (see docs/architecture/migration-roadmap.md).
class LocalPersistenceService {
  /// Per-user, like every other feature cache: timeline memories are private
  /// couple data, and a device-wide key let a second account signing in read
  /// the previous one's until the network sync replaced them. See
  /// [ScopedJsonCache].
  static const ScopedJsonCache _timelineCache = ScopedJsonCache(
    'timeline_items',
  );

  /// Deliberately NOT scoped. This is the theme and music preference -- device
  /// chrome, not couple data -- and scoping it would reset a returning user's
  /// theme for no privacy gain.
  static const String _settingsKey = PrefsKeys.appSettings;

  Future<void> saveTimelineItems(List<TimelineItemData> items) async {
    final jsonList = items.map((item) => item.toJson()).toList();
    await _timelineCache.write(jsonEncode(jsonList));
  }

  Future<List<TimelineItemData>> loadTimelineItems() async {
    final jsonString = await _timelineCache.read();

    if (jsonString == null) {
      return [];
    }

    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => TimelineItemData.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_settingsKey);

    if (jsonString == null) {
      return AppSettings();
    }

    try {
      final json = jsonDecode(jsonString);
      return AppSettings.fromJson(json);
    } catch (e) {
      return AppSettings();
    }
  }

  Future<String> saveImageToStorage(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final newPath = '${directory.path}/$fileName';

    await imageFile.copy(newPath);
    return newPath;
  }

  Future<void> deleteImage(String imagePath) async {
    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
