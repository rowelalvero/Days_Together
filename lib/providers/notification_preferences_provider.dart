import 'package:days_together/models/notification_preferences_model.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/services/relationship_lifecycle_manager.dart';

class NotificationPreferencesProvider extends RelationshipLifecycleProvider {
  NotificationPreferences? _preferences;
  bool _isLoading = false;

  NotificationPreferences? get preferences => _preferences;
  bool get isLoading => _isLoading;

  @override
  Future<void> purgeCache() async {
    _preferences = null;
    if (!isDisposed) notifyListeners();
  }

  @override
  Future<void> syncInitialData() async {
    if (userId != null) {
      await _loadPreferences(userId!);
    }
  }

  Future<void> _loadPreferences(String userId) async {
    _isLoading = true;
    if (!isDisposed) notifyListeners();

    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('user_notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (res != null) {
        _preferences = NotificationPreferences.fromJson(res);
        // Sync local timezone if it differs
        final localTz = DateTime.now().timeZoneName;
        if (_preferences!.timezone != localTz) {
          await updatePreference('timezone', localTz);
        }
      } else {
        // Create default row
        final defaultPref = NotificationPreferences(
          userId: userId,
          timezone: DateTime.now().timeZoneName,
        );
        await client.from('user_notification_preferences').insert(defaultPref.toJson());
        _preferences = defaultPref;
      }
    } catch (e) {
      debugPrint('NotificationPreferencesProvider: Error loading preferences: $e');
    } finally {
      _isLoading = false;
      if (!isDisposed) notifyListeners();
    }
  }

  Future<void> updatePreference(String key, dynamic value) async {
    if (_preferences == null) return;

    final updatedJson = _preferences!.toJson();
    updatedJson[key] = value;
    updatedJson['updated_at'] = DateTime.now().toUtc().toIso8601String();

    try {
      final client = Supabase.instance.client;
      await client
          .from('user_notification_preferences')
          .upsert(updatedJson);

      _preferences = NotificationPreferences.fromJson(updatedJson);
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationPreferencesProvider: Error updating preference $key: $e');
    }
  }

  Future<void> togglePreference(String key) async {
    if (_preferences == null) return;
    final currentJson = _preferences!.toJson();
    final currentValue = currentJson[key];
    if (currentValue is bool) {
      await updatePreference(key, !currentValue);
    }
  }
}
