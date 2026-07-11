import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/services/supabase_sync_service.dart';
import 'package:days_together/models/calendar_event_model.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/recent_activity_service.dart';
import 'package:days_together/services/realtime_subscription_manager.dart';

import 'package:days_together/services/relationship_lifecycle_manager.dart';

class CalendarProvider extends SupabaseLifecycleProvider {
  static const String _storageKey = 'calendar_events';
  List<CalendarEvent> _events = [];
  bool _isLoading = true;
  final Set<String> _localMutations = {};

  List<CalendarEvent> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;

  @override
  String get tableName => 'calendar_events';

  CalendarProvider() : super() {
    _loadEvents();
  }

  @override
  Future<void> purgeCache() async {
    _events = [];
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
          .from('calendar_events')
          .select()
          .eq('couple_id', coupleId!);
      final parsed = res.map((data) {
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
          date: data['date'] != null
              ? DateTime.parse(data['date'] as String)
              : DateTime.now(),
          time: (hour != null && minute != null)
              ? TimeOfDay(hour: hour, minute: minute)
              : null,
          type: type,
          isRecurringYearly: data['is_recurring_yearly'] ?? false,
        );
      }).toList();

      _events = parsed;
      await _persistLocalOnly();
      if (!isDisposed) notifyListeners();
    } catch (e) {
      debugPrint('CalendarProvider.syncInitialData error: $e');
    }
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    final incoming = dataList.map((data) {
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
        time: hour != null && minute != null ? TimeOfDay(hour: hour, minute: minute) : null,
        type: type,
        isRecurringYearly: data['is_recurring_yearly'] ?? false,
      );
    }).toList();

    if (!_isLoading) {
      // Detect additions by partner
      final added = incoming.where((inc) => !_events.any((old) => old.id == inc.id)).toList();
      for (var event in added) {
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

      // Detect edits by partner
      final updated = incoming.where((inc) {
        final match = _events.firstWhere((old) => old.id == inc.id, orElse: () => CalendarEvent(id: '', title: '', date: DateTime.now(), type: CalendarEventType.other));
        return match.id.isNotEmpty && (match.title != inc.title || match.description != inc.description || match.date != inc.date);
      }).toList();
      for (var event in updated) {
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

      // Detect deletions by partner
      final deleted = _events.where((old) => !incoming.any((inc) => inc.id == old.id)).toList();
      for (var event in deleted) {
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

    _events = incoming;
    _isLoading = false;
    if (!isDisposed) notifyListeners();
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('CalendarProvider: Supabase sync error: $error');
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    _isLoading = true;
    if (!isDisposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _events = jsonList
            .map((json) => CalendarEvent.fromJson(json))
            .toList();
      } else {
        _events = [];
      }
    } catch (e, st) {
      debugPrint('CalendarProvider._loadEvents failed: $e\n$st');
    } finally {
      _isLoading = false;
      if (!isDisposed) notifyListeners();
    }
  }

  Future<void> addEvent(CalendarEvent event) async {
    _localMutations.add(event.id);
    if (coupleId != null) {
      try {
        await Supabase.instance.client
            .from('calendar_events')
            .upsert({
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
      } catch (e) {
        debugPrint('CalendarProvider.addEvent Supabase error: $e');
        _events.add(event);
        await _persist();
      }
    } else {
      _events.add(event);
      await _persist();
    }

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
        await Supabase.instance.client
            .from('calendar_events')
            .update({
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
        debugPrint('CalendarProvider.updateEvent Supabase error: $e');
        final index = _events.indexWhere((e) => e.id == updatedEvent.id);
        if (index != -1) {
          _events[index] = updatedEvent;
          await _persist();
        }
      }
    } else {
      final index = _events.indexWhere((e) => e.id == updatedEvent.id);
      if (index == -1) return;
      _events[index] = updatedEvent;
      await _persist();
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: 'Calendar event updated',
      description: 'Updated: "${updatedEvent.title}"',
      icon: '✏️',
      referenceId: updatedEvent.id,
      route: 'calendar',
    );
  }

  Future<void> deleteEvent(String id) async {
    _localMutations.add(id);
    final eventToDelete = _events.firstWhere((e) => e.id == id, orElse: () => CalendarEvent(id: id, title: 'Event', date: DateTime.now(), type: CalendarEventType.date));
    if (coupleId != null) {
      try {
        await Supabase.instance.client
            .from('calendar_events')
            .delete()
            .eq('id', id);
        NotificationService().sendPartnerNotification(
          title: 'Calendar Event Deleted 📅',
          body: 'Your partner removed a calendar event.',
          feature: 'calendar',
          itemId: id,
        );
      } catch (e) {
        debugPrint('CalendarProvider.deleteEvent Supabase error: $e');
        _events.removeWhere((e) => e.id == id);
        await _persist();
      }
    } else {
      _events.removeWhere((e) => e.id == id);
      await _persist();
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'deleted',
      title: 'Calendar event deleted',
      description: 'Deleted: "${eventToDelete.title}"',
      icon: '🗑️',
      referenceId: id,
      route: 'calendar',
    );
  }

  List<CalendarEvent> getEventsForDay(DateTime day) {
    return _events.where((event) {
      if (event.isRecurringYearly) {
        return event.date.month == day.month && event.date.day == day.day;
      }
      return event.date.year == day.year &&
          event.date.month == day.month &&
          event.date.day == day.day;
    }).toList();
  }

  Future<void> _persist() async {
    await _persistLocalOnly();
    if (!isDisposed) notifyListeners();
  }

  Future<void> _persistLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _events.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('CalendarProvider._persistLocalOnly failed: $e\n$st');
    }
  }

}
