import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/services/supabase_sync_service.dart';
import 'package:days_together/models/calendar_event_model.dart';
import 'package:days_together/providers/relationship_provider.dart';

class CalendarProvider with ChangeNotifier {
  static const String _storageKey = 'calendar_events';
  List<CalendarEvent> _events = [];
  bool _isLoading = true;
  bool _disposed = false;

  String? _coupleId;
  String? _userId;
  StreamSubscription? _syncSub;

  List<CalendarEvent> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;

  CalendarProvider() {
    _loadEvents();
  }

  void updateRelationship(RelationshipProvider relationship) {
    if (_coupleId != relationship.coupleId || _userId != relationship.userId) {
      _coupleId = relationship.coupleId;
      _userId = relationship.userId;

      _syncSub?.cancel();
      _syncSub = null;

      if (_coupleId != null && _userId != null && relationship.isFirebaseAvailable) {
        _initSupabaseSync();
      } else {
        _loadEvents();
      }
    }
  }

  void _initSupabaseSync() {
    if (_coupleId == null) return;
    _isLoading = true;
    if (!_disposed) notifyListeners();

    _syncSub = SupabaseSyncService.instance.subscribeToCoupleData(
      tableName: 'calendar_events',
      coupleId: _coupleId!,
      onData: (dataList) {
      _events = dataList.map((data) {
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

      _isLoading = false;
      if (!_disposed) notifyListeners();

      _persistLocalOnly();
      },
      onError: (err) {
        debugPrint('CalendarProvider: Supabase sync error: $err');
        _loadEvents();
      },
    );
  }

  Future<void> _loadEvents() async {
    _isLoading = true;
    if (!_disposed) notifyListeners();
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
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> addEvent(CalendarEvent event) async {
    if (_coupleId != null) {
      try {
        await Supabase.instance.client
            .from('calendar_events')
            .upsert({
          'id': event.id,
          'couple_id': _coupleId,
          'title': event.title,
          'description': event.description,
          'date': event.date.toIso8601String(),
          'hour': event.time?.hour,
          'minute': event.time?.minute,
          'type': event.type.index,
          'is_recurring_yearly': event.isRecurringYearly,
        });
      } catch (e) {
        debugPrint('CalendarProvider.addEvent Supabase error: $e');
        _events.add(event);
        await _persist();
      }
    } else {
      _events.add(event);
      await _persist();
    }
  }

  Future<void> updateEvent(CalendarEvent updatedEvent) async {
    if (_coupleId != null) {
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
  }

  Future<void> deleteEvent(String id) async {
    if (_coupleId != null) {
      try {
        await Supabase.instance.client
            .from('calendar_events')
            .delete()
            .eq('id', id);
      } catch (e) {
        debugPrint('CalendarProvider.deleteEvent Supabase error: $e');
        _events.removeWhere((e) => e.id == id);
        await _persist();
      }
    } else {
      _events.removeWhere((e) => e.id == id);
      await _persist();
    }
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
    if (!_disposed) notifyListeners();
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

  @override
  void dispose() {
    _syncSub?.cancel();
    _disposed = true;
    super.dispose();
  }
}
