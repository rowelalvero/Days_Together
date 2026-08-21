import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/features/love_studio/time_capsule_state.dart';
import 'package:days_together/models/time_capsule_model.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/recent_activity_service.dart';

/// Riverpod port of `TimeCapsuleProvider` (Phase 6a of the architecture
/// migration). Faithful behavior port: like `GiftReminderController`/
/// `CalendarController`, writes do not apply locally on the Supabase
/// success path -- they rely on the realtime echo, matching the original
/// exactly. Also preserves a pre-existing asymmetry: `syncInitialData`
/// converts `open_date`/`created_at` `.toLocal()`, but `onRealtimeData`
/// does not -- both copied verbatim from the original.
class TimeCapsuleController extends Notifier<TimeCapsuleState>
    with SupabaseLifecycleNotifier<TimeCapsuleState> {
  static const String _storageKey = 'time_capsules';
  final Set<String> _localMutations = {};

  @override
  String get tableName => 'time_capsules';

  @override
  TimeCapsuleState build() {
    initSessionLifecycle();
    _loadFromCache();
    return const TimeCapsuleState();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      final capsules = jsonString != null
          ? ((jsonDecode(jsonString) as List).map((json) => TimeCapsule.fromJson(json)).toList()
            ..sort((a, b) => a.openDate.compareTo(b.openDate)))
          : <TimeCapsule>[];
      if (!ref.mounted) return;
      state = state.copyWith(capsules: capsules, isLoading: false);
    } catch (e, st) {
      debugPrint('TimeCapsuleController._loadFromCache failed: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  @override
  Future<void> purgeCache() async {
    state = state.copyWith(capsules: [], isLoading: false);
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
          await Supabase.instance.client.from('time_capsules').select().eq('couple_id', coupleId!);
      final parsed = res.map((data) {
        return TimeCapsule(
          id: data['id'] as String,
          message: data['message'] ?? '',
          openDate: data['open_date'] != null ? DateTime.parse(data['open_date'] as String).toLocal() : DateTime.now(),
          isOpened: data['is_opened'] ?? false,
          createdAt:
              data['created_at'] != null ? DateTime.parse(data['created_at'] as String).toLocal() : DateTime.now(),
        );
      }).toList()
        ..sort((a, b) => a.openDate.compareTo(b.openDate));

      if (!ref.mounted) return;
      state = state.copyWith(capsules: parsed, isLoading: false);
      await _persistLocalOnly();
    } catch (e) {
      debugPrint('TimeCapsuleController.syncInitialData error: $e');
    }
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    if (!ref.mounted) return;
    final incoming = dataList.map((data) {
      return TimeCapsule(
        id: data['id'] as String,
        message: data['message'] ?? '',
        openDate: data['open_date'] != null ? DateTime.parse(data['open_date'] as String) : DateTime.now(),
        isOpened: data['is_opened'] ?? false,
        createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'] as String) : DateTime.now(),
      );
    }).toList()
      ..sort((a, b) => a.openDate.compareTo(b.openDate));

    final wasLoading = state.isLoading;
    final oldCapsules = state.capsules;

    if (!wasLoading) {
      final added = incoming.where((inc) => !oldCapsules.any((old) => old.id == inc.id)).toList();
      for (final capsule in added) {
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

      final opened = incoming
          .where((inc) => inc.isOpened && !oldCapsules.any((old) => old.id == inc.id && old.isOpened))
          .toList();
      for (final capsule in opened) {
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

    state = state.copyWith(capsules: incoming, isLoading: false);
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('TimeCapsuleController: Supabase sync error: $error');
    _loadFromCache();
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
          body: 'Your partner locked a new time capsule to be opened on $openDateStr!',
          feature: 'time_capsule',
          itemId: capsule.id,
        );
      } catch (e) {
        debugPrint('TimeCapsuleController.createCapsule Supabase error: $e');
        if (!ref.mounted) return;
        await _createLocalCapsule(capsule);
      }
    } else {
      await _createLocalCapsule(capsule);
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Time Capsule created ⏳',
      description: 'Locked a new time capsule to be opened later',
      icon: '⏳',
      referenceId: capsule.id,
      route: 'time_capsule',
    );
  }

  Future<void> _createLocalCapsule(TimeCapsule capsule) async {
    final capsules = [...state.capsules, capsule]..sort((a, b) => a.openDate.compareTo(b.openDate));
    state = state.copyWith(capsules: capsules);
    await _persist();
  }

  Future<void> openCapsule(String id) async {
    _localMutations.add(id);
    final index = state.capsules.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final capsule = state.capsules[index];
    if (!capsule.canOpen) return;

    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('time_capsules').update({'is_opened': true}).eq('id', id);
        NotificationService().sendPartnerNotification(
          title: 'Time Capsule Opened 🔓',
          body: 'Your partner opened a time capsule!',
          feature: 'time_capsule',
          itemId: id,
        );
      } catch (e) {
        debugPrint('TimeCapsuleController.openCapsule Supabase error: $e');
        if (!ref.mounted) return;
        await _openLocalCapsule(id, capsule);
      }
    } else {
      await _openLocalCapsule(id, capsule);
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'completed',
      title: 'Time Capsule opened 🔓',
      description: 'Opened a locked time capsule',
      icon: '🔓',
      referenceId: id,
      route: 'time_capsule',
    );
  }

  Future<void> _openLocalCapsule(String id, TimeCapsule capsule) async {
    final index = state.capsules.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final capsules = [...state.capsules];
    capsules[index] = capsule.copyWith(isOpened: true);
    state = state.copyWith(capsules: capsules);
    await _persist();
  }

  Future<void> deleteCapsule(String id) async {
    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('time_capsules').delete().eq('id', id);
      } catch (e) {
        debugPrint('TimeCapsuleController.deleteCapsule Supabase error: $e');
        if (!ref.mounted) return;
        await _deleteLocalCapsule(id);
      }
    } else {
      await _deleteLocalCapsule(id);
    }
  }

  Future<void> _deleteLocalCapsule(String id) async {
    state = state.copyWith(capsules: state.capsules.where((c) => c.id != id).toList());
    await _persist();
  }

  Future<void> _persist() => _persistLocalOnly();

  Future<void> _persistLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.capsules.map((c) => c.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('TimeCapsuleController._persistLocalOnly failed: $e\n$st');
    }
  }
}

final timeCapsuleControllerProvider = NotifierProvider.autoDispose<TimeCapsuleController, TimeCapsuleState>(
  TimeCapsuleController.new,
  dependencies: [coupleSessionProvider],
);
