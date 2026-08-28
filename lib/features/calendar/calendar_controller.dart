import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/features/calendar/calendar_state.dart';
import 'package:days_together/models/calendar_event_model.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/recent_activity_service.dart';

/// Riverpod port of `CalendarProvider` (Phase 6a of the architecture
/// migration). Faithful behavior port: like `GiftReminderController` (and
/// unlike `BucketListController`), none of the three write methods apply
/// locally on the Supabase success path -- they rely entirely on the
/// realtime echo, matching the original exactly.
class CalendarController extends Notifier<CalendarState> with SupabaseLifecycleNotifier<CalendarState> {
  static const String _storageKey = 'calendar_events';
  final Set<String> _localMutations = {};

  @override
  String get tableName => 'calendar_events';

  @override
  CalendarState build() {
    initSessionLifecycle();
    _loadFromCache();
    return const CalendarState();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      final events = jsonString != null
          ? (jsonDecode(jsonString) as List).map((json) => CalendarEvent.fromJson(json)).toList()
          : <CalendarEvent>[];
      if (!ref.mounted) return;
      state = state.copyWith(events: events, isLoading: false);
    } catch (e, st) {
      debugPrint('CalendarController._loadFromCache failed: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  @override
  Future<void> purgeCache() async {
    state = state.copyWith(events: [], isLoading: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('CalendarController.purgeCache error: $e');
    }
  }

  CalendarEvent _parseEvent(Map<String, dynamic> data) {
    final hour = data['hour'] as int?;
    final minute = data['minute'] as int?;
    final typeIndex = data['type'] as int? ?? 4;
    final type = (typeIndex >= 0 && typeIndex < CalendarEventType.values.length)
        ? CalendarEventType.values[typeIndex]
        : CalendarEventType.other;

    return CalendarEvent(
      id: data['id'] as String,
      title: data['title'] ?? '',
      description: data['description'] as String?,
      date: data['date'] != null ? DateTime.parse(data['date'] as String) : DateTime.now(),
      time: (hour != null && minute != null) ? TimeOfDay(hour: hour, minute: minute) : null,
      type: type,
      isRecurringYearly: data['is_recurring_yearly'] ?? false,
    );
  }

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    try {
      final List<dynamic> res =
          await Supabase.instance.client.from('calendar_events').select().eq('couple_id', coupleId!);
      final parsed = res.map((data) => _parseEvent(data)).toList();

      if (!ref.mounted) return;
      state = state.copyWith(events: parsed, isLoading: false);
      await _persistLocalOnly();
    } catch (e) {
      debugPrint('CalendarController.syncInitialData error: $e');
    }
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    if (!ref.mounted) return;
    final incoming = dataList.map((data) => _parseEvent(data)).toList();
    final wasLoading = state.isLoading;
    final oldEvents = state.events;

    if (!wasLoading) {
      final added = incoming.where((inc) => !oldEvents.any((old) => old.id == inc.id)).toList();
      for (final event in added) {
        if (_localMutations.contains(event.id)) {
          _localMutations.remove(event.id);
          continue;
        }
        RecentActivityService.instance.logActivity(
          activityType: 'created',
          title: "Partner's calendar event created",
          description: 'Created: "${event.title}"',
          icon: '📅',
          referenceId: event.id,
          route: 'calendar',
        );
      }

      final updated = incoming.where((inc) {
        final match = oldEvents.firstWhere(
          (old) => old.id == inc.id,
          orElse: () => CalendarEvent(id: '', title: '', date: DateTime.now(), type: CalendarEventType.other),
        );
        return match.id.isNotEmpty &&
            (match.title != inc.title || match.description != inc.description || match.date != inc.date);
      }).toList();
      for (final event in updated) {
        if (_localMutations.contains(event.id)) {
          _localMutations.remove(event.id);
          continue;
        }
        RecentActivityService.instance.logActivity(
          activityType: 'updated',
          title: "Partner's calendar event updated",
          description: 'Updated: "${event.title}"',
          icon: '✏️',
          referenceId: event.id,
          route: 'calendar',
        );
      }

      final deleted = oldEvents.where((old) => !incoming.any((inc) => inc.id == old.id)).toList();
      for (final event in deleted) {
        if (_localMutations.contains(event.id)) {
          _localMutations.remove(event.id);
          continue;
        }
        RecentActivityService.instance.logActivity(
          activityType: 'deleted',
          title: "Partner's calendar event deleted",
          description: 'Deleted: "${event.title}"',
          icon: '🗑️',
          referenceId: event.id,
          route: 'calendar',
        );
      }
    }

    state = state.copyWith(events: incoming, isLoading: false);
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('CalendarController: Supabase sync error: $error');
    _loadFromCache();
  }

  Future<void> addEvent(CalendarEvent event) async {
    _localMutations.add(event.id);
    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('calendar_events').upsert({
          'id': event.id,
          'couple_id': coupleId,
          'title': event.title,
          'description': event.description,
          'date': event.date.toIso8601String(),
          'hour': event.time?.hour,
          'minute': event.time?.minute,
          'type': event.type.index,
          'is_recurring_yearly': event.isRecurringYearly,
        });
        NotificationService().sendPartnerNotification(
          title: 'New Calendar Event 📅',
          body: 'Your partner added an event: "${event.title}"',
          feature: 'calendar',
          itemId: event.id,
        );
        // No local apply on success, matching the original: relies on the
        // realtime echo.
      } catch (e) {
        debugPrint('CalendarController.addEvent Supabase error: $e');
        if (!ref.mounted) return;
        state = state.copyWith(events: [...state.events, event]);
        await _persist();
      }
    } else {
      state = state.copyWith(events: [...state.events, event]);
      await _persist();
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Calendar event created',
      description: 'Created: "${event.title}"',
      icon: '📅',
      referenceId: event.id,
      route: 'calendar',
    );
  }

  Future<void> updateEvent(CalendarEvent updatedEvent) async {
    _localMutations.add(updatedEvent.id);
    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('calendar_events').update({
          'title': updatedEvent.title,
          'description': updatedEvent.description,
          'date': updatedEvent.date.toIso8601String(),
          'hour': updatedEvent.time?.hour,
          'minute': updatedEvent.time?.minute,
          'type': updatedEvent.type.index,
          'is_recurring_yearly': updatedEvent.isRecurringYearly,
        }).eq('id', updatedEvent.id);
        NotificationService().sendPartnerNotification(
          title: 'Calendar Event Updated 📅',
          body: 'Your partner updated the event: "${updatedEvent.title}"',
          feature: 'calendar',
          itemId: updatedEvent.id,
        );
      } catch (e) {
        debugPrint('CalendarController.updateEvent Supabase error: $e');
        if (!ref.mounted) return;
        _replaceEvent(updatedEvent);
        await _persist();
      }
    } else {
      if (!state.events.any((e) => e.id == updatedEvent.id)) return;
      _replaceEvent(updatedEvent);
      await _persist();
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: 'Calendar event updated',
      description: 'Updated: "${updatedEvent.title}"',
      icon: '✏️',
      referenceId: updatedEvent.id,
      route: 'calendar',
    );
  }

  void _replaceEvent(CalendarEvent updatedEvent) {
    final index = state.events.indexWhere((e) => e.id == updatedEvent.id);
    if (index == -1) return;
    final events = [...state.events];
    events[index] = updatedEvent;
    state = state.copyWith(events: events);
  }

  Future<void> deleteEvent(String id) async {
    _localMutations.add(id);
    final eventToDelete = state.events.firstWhere(
      (e) => e.id == id,
      orElse: () => CalendarEvent(id: id, title: 'Event', date: DateTime.now(), type: CalendarEventType.date),
    );
    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('calendar_events').delete().eq('id', id);
        NotificationService().sendPartnerNotification(
          title: 'Calendar Event Deleted 📅',
          body: 'Your partner removed a calendar event.',
          feature: 'calendar',
          itemId: id,
        );
      } catch (e) {
        debugPrint('CalendarController.deleteEvent Supabase error: $e');
        if (!ref.mounted) return;
        state = state.copyWith(events: state.events.where((e) => e.id != id).toList());
        await _persist();
      }
    } else {
      state = state.copyWith(events: state.events.where((e) => e.id != id).toList());
      await _persist();
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'deleted',
      title: 'Calendar event deleted',
      description: 'Deleted: "${eventToDelete.title}"',
      icon: '🗑️',
      referenceId: id,
      route: 'calendar',
    );
  }

  Future<void> _persist() => _persistLocalOnly();

  Future<void> _persistLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.events.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('CalendarController._persistLocalOnly failed: $e\n$st');
    }
  }
}

final calendarControllerProvider = NotifierProvider.autoDispose<CalendarController, CalendarState>(
  CalendarController.new,
  dependencies: [coupleSessionProvider],
);
