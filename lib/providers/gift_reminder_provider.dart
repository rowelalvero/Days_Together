import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/services/supabase_sync_service.dart';
import 'package:days_together/models/gift_reminder_model.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/recent_activity_service.dart';

class GiftReminderProvider with ChangeNotifier {
  static const String _storageKey = 'gift_reminders';
  List<GiftReminder> _reminders = [];
  bool _isLoading = true;
  bool _disposed = false;

  String? _coupleId;
  String? _userId;
  StreamSubscription? _syncSub;

  List<GiftReminder> get reminders => List.unmodifiable(_reminders);
  List<GiftReminder> get upcomingReminders {
    final sorted = List<GiftReminder>.from(_reminders)
      ..sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return sorted;
  }
  bool get isLoading => _isLoading;

  GiftReminderProvider() {
    _loadReminders();
  }

  void updateRelationship(RelationshipProvider relationship) {
    final bool credentialsChanged = _coupleId != relationship.coupleId || _userId != relationship.userId;
    final bool shouldSubscribe = _syncSub == null && relationship.coupleId != null && relationship.userId != null && relationship.isFirebaseAvailable;

    if (credentialsChanged || shouldSubscribe) {
      _coupleId = relationship.coupleId;
      _userId = relationship.userId;

      _syncSub?.cancel();
      _syncSub = null;

      if (_coupleId != null && _userId != null && relationship.isFirebaseAvailable) {
        _initSupabaseSync();
      } else {
        _loadReminders();
      }
    }
  }

  void _initSupabaseSync() {
    if (_coupleId == null) return;
    _isLoading = true;
    if (!_disposed) notifyListeners();

    _syncSub = SupabaseSyncService.instance.subscribeToCoupleData(
      tableName: 'gift_reminders',
      coupleId: _coupleId!,
      onData: (dataList) {
        final incoming = dataList.map((data) {
          return GiftReminder(
            id: data['id'] as String,
            title: data['title'] ?? '',
            date: data['date'] != null ? DateTime.parse(data['date'] as String) : DateTime.now(),
            reminderDaysBefore: List<int>.from(data['reminder_days_before'] ?? [30, 14, 7]),
            isEnabled: data['is_enabled'] ?? true,
            isRecurringYearly: data['is_recurring_yearly'] ?? true,
            createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'] as String) : DateTime.now(),
          );
        }).toList();

        if (!_isLoading) {
          // Detect additions by partner
          final added = incoming.where((inc) => !_reminders.any((old) => old.id == inc.id)).toList();
          for (var reminder in added) {
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
          final completed = incoming.where((inc) => !inc.isEnabled && !_reminders.any((old) => old.id == inc.id && !old.isEnabled)).toList();
          for (var reminder in completed) {
            final existedAndWasEnabled = _reminders.any((old) => old.id == reminder.id && old.isEnabled);
            if (existedAndWasEnabled) {
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
          final deleted = _reminders.where((old) => !incoming.any((inc) => inc.id == old.id)).toList();
          for (var reminder in deleted) {
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
        if (!_disposed) notifyListeners();
        _persistLocalOnly();
      },
      onError: (err) {
        debugPrint('GiftReminderProvider: Supabase sync error: $err');
        _loadReminders();
      },
    );
  }

  Future<void> _loadReminders() async {
    _isLoading = true;
    if (!_disposed) notifyListeners();
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
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> addReminder(String title, DateTime date) async {
    final reminder = GiftReminder(title: title, date: date);

    if (_coupleId != null) {
      try {
        await Supabase.instance.client
            .from('gift_reminders')
            .upsert({
          'id': reminder.id,
          'couple_id': _coupleId,
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

  Future<void> updateReminder(String id, {String? title, DateTime? date}) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;

    if (_coupleId != null) {
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
          body: 'Your partner updated the gift reminder: "${title ?? 'Reminder'}"',
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
      _reminders[index] = _reminders[index].copyWith(
        title: title,
        date: date,
      );
      await _persist();
    }
  }

  Future<void> toggleReminder(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final nextEnabled = !_reminders[index].isEnabled;

    if (_coupleId != null) {
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
    if (_coupleId != null) {
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
    if (!_disposed) notifyListeners();
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

  @override
  void dispose() {
    _syncSub?.cancel();
    _disposed = true;
    super.dispose();
  }
}
