import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/models/timeline_model.dart';

class TimelineRepository {
  static const String _timelineKey = 'timeline_items';
  static const String _settingsKey = 'app_settings';

  Future<void> saveTimelineItems(List<TimelineItemData> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = items.map((item) => item.toJson()).toList();
    await prefs.setString(_timelineKey, jsonEncode(jsonList));
  }

  Future<List<TimelineItemData>> loadTimelineItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_timelineKey);
    
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