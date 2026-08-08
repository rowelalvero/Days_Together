import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/models/time_capsule_model.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/recent_activity_service.dart';

import 'package:days_together/services/relationship_lifecycle_manager.dart';

class TimeCapsuleProvider extends SupabaseLifecycleProvider {
  static const String _storageKey = 'time_capsules';
  List<TimeCapsule> _capsules = [];
  bool _isLoading = true;
  final Set<String> _localMutations = {};

  List<TimeCapsule> get capsules => List.unmodifiable(_capsules);
  List<TimeCapsule> get lockedCapsules =>
      _capsules.where((c) => !c.isOpened && !c.canOpen).toList();
  List<TimeCapsule> get openableCapsules =>
      _capsules.where((c) => !c.isOpened && c.canOpen).toList();
  List<TimeCapsule> get openedCapsules =>
      _capsules.where((c) => c.isOpened).toList();
  bool get isLoading => _isLoading;

  @override
  String get tableName => 'time_capsules';

  TimeCapsuleProvider() : super() {
    _loadCapsules();
  }

  @override
  Future<void> purgeCache() async {
    _capsules = [];
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
          .from('time_capsules')
          .select()
          .eq('couple_id', coupleId!);
      final parsed = res.map((data) {
        return TimeCapsule(
          id: data['id'] as String,
          message: data['message'] ?? '',
          openDate: data['open_date'] != null
              ? DateTime.parse(data['open_date'] as String).toLocal()
              : DateTime.now(),
          isOpened: data['is_opened'] ?? false,
          createdAt: data['created_at'] != null
              ? DateTime.parse(data['created_at'] as String).toLocal()
              : DateTime.now(),
        );
      }).toList()..sort((a, b) => a.openDate.compareTo(b.openDate));

      _capsules = parsed;
      await _persistLocalOnly();
      if (!isDisposed) notifyListeners();
    } catch (e) {
      debugPrint('TimeCapsuleProvider.syncInitialData error: $e');
    }
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    final incoming = dataList.map((data) {
      return TimeCapsule(
        id: data['id'] as String,
        message: data['message'] ?? '',
        openDate: data['open_date'] != null
            ? DateTime.parse(data['open_date'] as String)
            : DateTime.now(),
        isOpened: data['is_opened'] ?? false,
        createdAt: data['created_at'] != null
            ? DateTime.parse(data['created_at'] as String)
            : DateTime.now(),
      );
    }).toList();

    incoming.sort((a, b) => a.openDate.compareTo(b.openDate));

    if (!_isLoading) {
      // Detect additions by partner
      final added = incoming
          .where((inc) => !_capsules.any((old) => old.id == inc.id))
          .toList();
      for (var capsule in added) {
        if (_localMutations.contains(capsule.id)) {
          _localMutations.remove(capsule.id);
          continue;
        }
        RecentActivityService.instance.logActivity(
          activityType: 'created',
          title: "Partner's time capsule created ⏳",
          description: 'Locked a new time capsule to be opened later',
          icon: '⏳',
          referenceId: capsule.id,
          route: 'time_capsule',
        );
      }

      // Detect openings by partner
      final opened = incoming
          .where(
            (inc) =>
                inc.isOpened &&
                !_capsules.any((old) => old.id == inc.id && old.isOpened),
          )
          .toList();
      for (var capsule in opened) {
        if (_localMutations.contains(capsule.id)) {
          _localMutations.remove(capsule.id);
          continue;
        }
        RecentActivityService.instance.logActivity(
          activityType: 'completed',
          title: "Partner's time capsule opened 🔓",
          description: 'Opened a locked time capsule',
          icon: '🔓',
          referenceId: capsule.id,
          route: 'time_capsule',
        );
      }
    }

    _capsules = incoming;
    _isLoading = false;
    if (!isDisposed) notifyListeners();
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('TimeCapsuleProvider: Supabase sync error: $error');
    _loadCapsules();
  }

  Future<void> _loadCapsules() async {
    _isLoading = true;
    if (!isDisposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _capsules = jsonList.map((json) => TimeCapsule.fromJson(json)).toList()
          ..sort((a, b) => a.openDate.compareTo(b.openDate));
      } else {
        _capsules = [];
      }
    } catch (e, st) {
      debugPrint('TimeCapsuleProvider._loadCapsules failed: $e\n$st');
    } finally {
      _isLoading = false;
      if (!isDisposed) notifyListeners();
    }
  }

  Future<void> createCapsule(String message, DateTime openDate) async {
    final capsule = TimeCapsule(message: message, openDate: openDate);
    _localMutations.add(capsule.id);

    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('time_capsules').upsert({
          'id': capsule.id,
          'couple_id': coupleId,
          'message': message,
          'open_date': openDate.toIso8601String(),
          'is_opened': capsule.isOpened,
          'created_at': DateTime.now().toIso8601String(),
        });
        final openDateStr = openDate.toLocal().toString().substring(0, 10);
        NotificationService().sendPartnerNotification(
          title: 'Time Capsule Created ⏳',
          body:
              'Your partner locked a new time capsule to be opened on $openDateStr!',
          feature: 'time_capsule',
          itemId: capsule.id,
        );
      } catch (e) {
        debugPrint('TimeCapsuleProvider.createCapsule Supabase error: $e');
        _createLocalCapsule(capsule);
      }
    } else {
      _createLocalCapsule(capsule);
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Time Capsule created ⏳',
      description: 'Locked a new time capsule to be opened later',
      icon: '⏳',
      referenceId: capsule.id,
      route: 'time_capsule',
    );
  }

  void _createLocalCapsule(TimeCapsule capsule) {
    _capsules.add(capsule);
    _capsules.sort((a, b) => a.openDate.compareTo(b.openDate));
    _persist();
  }

  Future<void> openCapsule(String id) async {
    _localMutations.add(id);
    final index = _capsules.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final capsule = _capsules[index];
    if (!capsule.canOpen) return;

    if (coupleId != null) {
      try {
        await Supabase.instance.client
            .from('time_capsules')
            .update({'is_opened': true})
            .eq('id', id);
        NotificationService().sendPartnerNotification(
          title: 'Time Capsule Opened 🔓',
          body: 'Your partner opened a time capsule!',
          feature: 'time_capsule',
          itemId: id,
        );
      } catch (e) {
        debugPrint('TimeCapsuleProvider.openCapsule Supabase error: $e');
        _openLocalCapsule(index, capsule);
      }
    } else {
      _openLocalCapsule(index, capsule);
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'completed',
      title: 'Time Capsule opened 🔓',
      description: 'Opened a locked time capsule',
      icon: '🔓',
      referenceId: id,
      route: 'time_capsule',
    );
  }

  void _openLocalCapsule(int index, TimeCapsule capsule) {
    _capsules[index] = capsule.copyWith(isOpened: true);
    _persist();
  }

  Future<void> deleteCapsule(String id) async {
    if (coupleId != null) {
      try {
        await Supabase.instance.client
            .from('time_capsules')
            .delete()
            .eq('id', id);
      } catch (e) {
        debugPrint('TimeCapsuleProvider.deleteCapsule Supabase error: $e');
        _deleteLocalCapsule(id);
      }
    } else {
      _deleteLocalCapsule(id);
    }
  }

  void _deleteLocalCapsule(String id) {
    _capsules.removeWhere((c) => c.id == id);
    _persist();
  }

  Future<void> _persist() async {
    await _persistLocalOnly();
    if (!isDisposed) notifyListeners();
  }

  Future<void> _persistLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _capsules.map((c) => c.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('TimeCapsuleProvider._persistLocalOnly failed: $e\n$st');
    }
  }
}
