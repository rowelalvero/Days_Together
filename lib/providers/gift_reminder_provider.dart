import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/models/gift_reminder_model.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/recent_activity_service.dart';

import 'package:days_together/services/relationship_lifecycle_manager.dart';

class GiftReminderProvider extends SupabaseLifecycleProvider {
  static const String _storageKey = 'gift_reminders';
  List<GiftReminder> _reminders = [];
  bool _isLoading = true;
  final Set<String> _localMutations = {};

  List<GiftReminder> get reminders => List.unmodifiable(_reminders);
  List<GiftReminder> get upcomingReminders {
    final sorted = List<GiftReminder>.from(_reminders)
      ..sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return sorted;
  }

  bool get isLoading => _isLoading;

  @override
  String get tableName => 'gift_reminders';

  GiftReminderProvider() : super() {
    _loadReminders();
  }

  @override
  Future<void> purgeCache() async {
    _reminders = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
    if (!isDisposed) notifyListeners();
  }

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    try {
      final List<dynamic> res = await Supabase.instance.client
          .from('gift_reminders')
          .select()
          .eq('couple_id', coupleId!);
      final parsed = res.map((data) {
        return GiftReminder(
          id: data['id'] as String,
          title: data['title'] ?? '',
          date: data['date'] != null
              ? DateTime.parse(data['date'] as String)
              : DateTime.now(),
        );
      }).toList();

      _reminders = parsed;
      await _persistLocalOnly();
      if (!isDisposed) notifyListeners();
    } catch (e) {
      debugPrint('GiftReminderProvider.syncInitialData error: $e');
    }
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    final incoming = dataList.map((data) {
      return GiftReminder(
        id: data['id'] as String,
        title: data['title'] ?? '',
        date: data['date'] != null
            ? DateTime.parse(data['date'] as String)
            : DateTime.now(),
        reminderDaysBefore: List<int>.from(
          data['reminder_days_before'] ?? [30, 14, 7],
        ),
        isEnabled: data['is_enabled'] ?? true,
        isRecurringYearly: data['is_recurring_yearly'] ?? true,
        createdAt: data['created_at'] != null
            ? DateTime.parse(data['created_at'] as String)
            : DateTime.now(),
      );
    }).toList();

    if (!_isLoading) {
      // Detect additions by partner
      final added = incoming
          .where((inc) => !_reminders.any((old) => old.id == inc.id))
          .toList();
      for (var reminder in added) {
        if (_localMutations.contains(reminder.id)) {
          _localMutations.remove(reminder.id);
          continue;
        }
        RecentActivityService.instance.logActivity(
          activityType: 'created',
          title: "Partner's gift reminder added",
          description: 'Added reminder: "${reminder.title}"',
          icon: '🎁',
          referenceId: reminder.id,
          route: 'gifts',
        );
      }

      // Detect completions by partner (isEnabled toggled to false by partner)
      final completed = incoming
          .where(
            (inc) =>
                !inc.isEnabled &&
                !_reminders.any((old) => old.id == inc.id && !old.isEnabled),
          )
          .toList();
      for (var reminder in completed) {
        final existedAndWasEnabled = _reminders.any(
          (old) => old.id == reminder.id && old.isEnabled,
        );
        if (existedAndWasEnabled) {
          if (_localMutations.contains(reminder.id)) {
            _localMutations.remove(reminder.id);
            continue;
          }
          RecentActivityService.instance.logActivity(
            activityType: 'completed',
            title: "Partner's gift reminder completed",
            description: 'Completed: "${reminder.title}"',
            icon: '🎁',
            referenceId: reminder.id,
            route: 'gifts',
          );
        }
      }

      // Detect deletions by partner
      final deleted = _reminders
          .where((old) => !incoming.any((inc) => inc.id == old.id))
          .toList();
      for (var reminder in deleted) {
        if (_localMutations.contains(reminder.id)) {
          _localMutations.remove(reminder.id);
          continue;
        }
        RecentActivityService.instance.logActivity(
          activityType: 'deleted',
          title: "Partner's gift reminder deleted",
          description: 'Deleted reminder: "${reminder.title}"',
          icon: '🗑️',
          referenceId: reminder.id,
          route: 'gifts',
        );
      }
    }

    _reminders = incoming;
    _isLoading = false;
    if (!isDisposed) notifyListeners();
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('GiftReminderProvider: Supabase sync error: $error');
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    _isLoading = true;
    if (!isDisposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _reminders = jsonList
            .map((json) => GiftReminder.fromJson(json))
            .toList();
      } else {
        _reminders = [];
      }
    } catch (e, st) {
      debugPrint('GiftReminderProvider._loadReminders failed: $e\n$st');
    } finally {
      _isLoading = false;
      if (!isDisposed) notifyListeners();
    }
  }

  Future<void> addReminder(String title, DateTime date) async {
    final reminder = GiftReminder(title: title, date: date);
    _localMutations.add(reminder.id);

    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('gift_reminders').upsert({
          'id': reminder.id,
          'couple_id': coupleId,
          'title': title,
          'date': date.toIso8601String(),
          'reminder_days_before': reminder.reminderDaysBefore,
          'is_enabled': reminder.isEnabled,
          'is_recurring_yearly': reminder.isRecurringYearly,
          'created_at': DateTime.now().toIso8601String(),
        });
        NotificationService().sendPartnerNotification(
          title: 'New Gift Idea / Reminder 🎁',
          body: 'Your partner added a gift reminder: "$title"',
          feature: 'gifts',
          itemId: reminder.id,
        );
      } catch (e) {
        debugPrint('GiftReminderProvider.addReminder Supabase error: $e');
        _reminders.add(reminder);
        await _persist();
      }
    } else {
      _reminders.add(reminder);
      await _persist();
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Gift Reminder added 🎁',
      description: 'Added reminder: "$title"',
      icon: '🎁',
      referenceId: reminder.id,
      route: 'gifts',
    );
  }

  Future<void> updateReminder(
    String id, {
    String? title,
    DateTime? date,
  }) async {
    _localMutations.add(id);
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;

    if (coupleId != null) {
      try {
        final updates = <String, dynamic>{};
        if (title != null) updates['title'] = title;
        if (date != null) updates['date'] = date.toIso8601String();

        await Supabase.instance.client
            .from('gift_reminders')
            .update(updates)
            .eq('id', id);
        NotificationService().sendPartnerNotification(
          title: 'Gift Reminder Updated 🎁',
          body:
              'Your partner updated the gift reminder: "${title ?? 'Reminder'}"',
          feature: 'gifts',
          itemId: id,
        );
      } catch (e) {
        debugPrint('GiftReminderProvider.updateReminder Supabase error: $e');
        _reminders[index] = _reminders[index].copyWith(
          title: title,
          date: date,
        );
        await _persist();
      }
    } else {
      _reminders[index] = _reminders[index].copyWith(title: title, date: date);
      await _persist();
    }
  }

  Future<void> toggleReminder(String id) async {
    _localMutations.add(id);
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final nextEnabled = !_reminders[index].isEnabled;

    if (coupleId != null) {
      try {
        await Supabase.instance.client
            .from('gift_reminders')
            .update({'is_enabled': nextEnabled})
            .eq('id', id);
      } catch (e) {
        debugPrint('GiftReminderProvider.toggleReminder Supabase error: $e');
        _reminders[index] = _reminders[index].copyWith(isEnabled: nextEnabled);
        await _persist();
      }
    } else {
      _reminders[index] = _reminders[index].copyWith(isEnabled: nextEnabled);
      await _persist();
    }

    final reminder = _reminders[index];
    if (!nextEnabled) {
      await RecentActivityService.instance.logActivity(
        activityType: 'completed',
        title: 'Gift Reminder completed 🎁',
        description: 'Completed: "${reminder.title}"',
        icon: '🎁',
        referenceId: id,
        route: 'gifts',
      );
    }
  }

  Future<void> deleteReminder(String id) async {
    _localMutations.add(id);
    if (coupleId != null) {
      try {
        await Supabase.instance.client
            .from('gift_reminders')
            .delete()
            .eq('id', id);
        NotificationService().sendPartnerNotification(
          title: 'Gift Reminder Deleted 🎁',
          body: 'Your partner removed a gift reminder.',
          feature: 'gifts',
          itemId: id,
        );
      } catch (e) {
        debugPrint('GiftReminderProvider.deleteReminder Supabase error: $e');
        _reminders.removeWhere((r) => r.id == id);
        await _persist();
      }
    } else {
      _reminders.removeWhere((r) => r.id == id);
      await _persist();
    }
  }

  Future<void> _persist() async {
    await _persistLocalOnly();
    if (!isDisposed) notifyListeners();
  }

  Future<void> _persistLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _reminders.map((r) => r.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('GiftReminderProvider._persistLocalOnly failed: $e\n$st');
    }
  }
}
