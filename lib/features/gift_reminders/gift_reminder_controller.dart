import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_state.dart';
import 'package:days_together/models/gift_reminder_model.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/recent_activity_service.dart';

/// Riverpod port of `GiftReminderProvider` (Phase 6a of the architecture
/// migration). Faithful behavior port, including a pre-existing asymmetry:
/// [syncInitialData] only parses `id`/`title`/`date` from the REST response
/// (not `reminderDaysBefore`/`isEnabled`/`isRecurringYearly`/`createdAt`,
/// which fall back to `GiftReminder`'s constructor defaults), while
/// [onRealtimeData] parses all fields -- meaning a REST-only resync (e.g.
/// app restart before the realtime subscription's first event) can
/// silently reset a disabled reminder's `isEnabled` back to `true` in
/// memory until the next realtime event corrects it. This is the original
/// `GiftReminderProvider.syncInitialData`'s exact behavior, preserved
/// as-is; not introduced by this port and out of scope to fix here.
class GiftReminderController extends Notifier<GiftReminderState>
    with SupabaseLifecycleNotifier<GiftReminderState> {
  static const String _storageKey = 'gift_reminders';
  final Set<String> _localMutations = {};

  @override
  String get tableName => 'gift_reminders';

  @override
  GiftReminderState build() {
    initSessionLifecycle();
    _loadFromCache();
    return const GiftReminderState();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      final reminders = jsonString != null
          ? (jsonDecode(jsonString) as List).map((json) => GiftReminder.fromJson(json)).toList()
          : <GiftReminder>[];
      if (!ref.mounted) return;
      state = state.copyWith(reminders: reminders, isLoading: false);
    } catch (e, st) {
      debugPrint('GiftReminderController._loadFromCache failed: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  @override
  Future<void> purgeCache() async {
    state = state.copyWith(reminders: [], isLoading: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    try {
      final List<dynamic> res =
          await Supabase.instance.client.from('gift_reminders').select().eq('couple_id', coupleId!);
      final parsed = res.map((data) {
        return GiftReminder(
          id: data['id'] as String,
          title: data['title'] ?? '',
          date: data['date'] != null ? DateTime.parse(data['date'] as String) : DateTime.now(),
        );
      }).toList();

      if (!ref.mounted) return;
      state = state.copyWith(reminders: parsed, isLoading: false);
      await _persistLocalOnly();
    } catch (e) {
      debugPrint('GiftReminderController.syncInitialData error: $e');
    }
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    if (!ref.mounted) return;
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

    final wasLoading = state.isLoading;
    final oldReminders = state.reminders;

    if (!wasLoading) {
      final added = incoming.where((inc) => !oldReminders.any((old) => old.id == inc.id)).toList();
      for (final reminder in added) {
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

      final completed = incoming
          .where((inc) => !inc.isEnabled && !oldReminders.any((old) => old.id == inc.id && !old.isEnabled))
          .toList();
      for (final reminder in completed) {
        final existedAndWasEnabled = oldReminders.any((old) => old.id == reminder.id && old.isEnabled);
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

      final deleted = oldReminders.where((old) => !incoming.any((inc) => inc.id == old.id)).toList();
      for (final reminder in deleted) {
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

    state = state.copyWith(reminders: incoming, isLoading: false);
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('GiftReminderController: Supabase sync error: $error');
    _loadFromCache();
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
        debugPrint('GiftReminderController.addReminder Supabase error: $e');
        if (!ref.mounted) return;
        state = state.copyWith(reminders: [...state.reminders, reminder]);
        await _persist();
      }
    } else {
      state = state.copyWith(reminders: [...state.reminders, reminder]);
      await _persist();
    }

    if (!ref.mounted) return;
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
    _localMutations.add(id);
    final index = state.reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;

    if (coupleId != null) {
      try {
        final updates = <String, dynamic>{};
        if (title != null) updates['title'] = title;
        if (date != null) updates['date'] = date.toIso8601String();

        await Supabase.instance.client.from('gift_reminders').update(updates).eq('id', id);
        NotificationService().sendPartnerNotification(
          title: 'Gift Reminder Updated 🎁',
          body: 'Your partner updated the gift reminder: "${title ?? 'Reminder'}"',
          feature: 'gifts',
          itemId: id,
        );
        // No local apply on success, matching the original exactly: the
        // update is expected to arrive back through the realtime echo.
      } catch (e) {
        debugPrint('GiftReminderController.updateReminder Supabase error: $e');
        if (!ref.mounted) return;
        _applyReminderUpdate(id, title: title, date: date);
        await _persist();
      }
    } else {
      _applyReminderUpdate(id, title: title, date: date);
      await _persist();
    }
  }

  void _applyReminderUpdate(String id, {String? title, DateTime? date}) {
    final index = state.reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final reminders = [...state.reminders];
    reminders[index] = reminders[index].copyWith(title: title, date: date);
    state = state.copyWith(reminders: reminders);
  }

  Future<void> toggleReminder(String id) async {
    _localMutations.add(id);
    final index = state.reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final nextEnabled = !state.reminders[index].isEnabled;

    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('gift_reminders').update({'is_enabled': nextEnabled}).eq('id', id);
      } catch (e) {
        debugPrint('GiftReminderController.toggleReminder Supabase error: $e');
        if (!ref.mounted) return;
        _applyToggle(id, nextEnabled);
        await _persist();
      }
    } else {
      _applyToggle(id, nextEnabled);
      await _persist();
    }

    if (!ref.mounted) return;
    final reminderIndex = state.reminders.indexWhere((r) => r.id == id);
    if (reminderIndex == -1) return;
    final reminder = state.reminders[reminderIndex];
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

  void _applyToggle(String id, bool nextEnabled) {
    final index = state.reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final reminders = [...state.reminders];
    reminders[index] = reminders[index].copyWith(isEnabled: nextEnabled);
    state = state.copyWith(reminders: reminders);
  }

  Future<void> deleteReminder(String id) async {
    _localMutations.add(id);
    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('gift_reminders').delete().eq('id', id);
        NotificationService().sendPartnerNotification(
          title: 'Gift Reminder Deleted 🎁',
          body: 'Your partner removed a gift reminder.',
          feature: 'gifts',
          itemId: id,
        );
        // No local removal on success, matching the original exactly: the
        // deletion is expected to arrive back through the realtime echo.
      } catch (e) {
        debugPrint('GiftReminderController.deleteReminder Supabase error: $e');
        if (!ref.mounted) return;
        state = state.copyWith(reminders: state.reminders.where((r) => r.id != id).toList());
        await _persist();
      }
    } else {
      state = state.copyWith(reminders: state.reminders.where((r) => r.id != id).toList());
      await _persist();
    }
  }

  Future<void> _persist() => _persistLocalOnly();

  Future<void> _persistLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.reminders.map((r) => r.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('GiftReminderController._persistLocalOnly failed: $e\n$st');
    }
  }
}

final giftReminderControllerProvider = NotifierProvider.autoDispose<GiftReminderController, GiftReminderState>(
  GiftReminderController.new,
  dependencies: [coupleSessionProvider],
);
