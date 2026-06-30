import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/services/supabase_sync_service.dart';
import 'package:days_together/models/time_capsule_model.dart';
import 'package:days_together/providers/relationship_provider.dart';

class TimeCapsuleProvider with ChangeNotifier {
  static const String _storageKey = 'time_capsules';
  List<TimeCapsule> _capsules = [];
  bool _isLoading = true;
  bool _disposed = false;

  String? _coupleId;
  String? _userId;
  StreamSubscription? _syncSub;

  List<TimeCapsule> get capsules => List.unmodifiable(_capsules);
  List<TimeCapsule> get lockedCapsules =>
      _capsules.where((c) => !c.isOpened && !c.canOpen).toList();
  List<TimeCapsule> get openableCapsules =>
      _capsules.where((c) => !c.isOpened && c.canOpen).toList();
  List<TimeCapsule> get openedCapsules =>
      _capsules.where((c) => c.isOpened).toList();
  bool get isLoading => _isLoading;

  TimeCapsuleProvider() {
    _loadCapsules();
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
        _loadCapsules();
      }
    }
  }

  void _initSupabaseSync() {
    if (_coupleId == null) return;
    _isLoading = true;
    if (!_disposed) notifyListeners();

    _syncSub = SupabaseSyncService.instance.subscribeToCoupleData(
      tableName: 'time_capsules',
      coupleId: _coupleId!,
      onData: (dataList) {
        _capsules = dataList.map((data) {
          return TimeCapsule(
            id: data['id'] as String,
            message: data['message'] ?? '',
            openDate: data['open_date'] != null ? DateTime.parse(data['open_date'] as String) : DateTime.now(),
            isOpened: data['is_opened'] ?? false,
            createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'] as String) : DateTime.now(),
          );
        }).toList();

        _capsules.sort((a, b) => a.openDate.compareTo(b.openDate));
        _isLoading = false;
        if (!_disposed) notifyListeners();

        _persistLocalOnly();
      },
      onError: (err) {
        debugPrint('TimeCapsuleProvider: Supabase sync error: $err');
        _loadCapsules();
      },
    );
  }

  Future<void> _loadCapsules() async {
    _isLoading = true;
    if (!_disposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _capsules = jsonList
            .map((json) => TimeCapsule.fromJson(json))
            .toList()
          ..sort((a, b) => a.openDate.compareTo(b.openDate));
      } else {
        _capsules = [];
      }
    } catch (e, st) {
      debugPrint('TimeCapsuleProvider._loadCapsules failed: $e\n$st');
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> createCapsule(String message, DateTime openDate) async {
    final capsule = TimeCapsule(message: message, openDate: openDate);

    if (_coupleId != null) {
      try {
        await Supabase.instance.client
            .from('time_capsules')
            .upsert({
          'id': capsule.id,
          'couple_id': _coupleId,
          'message': message,
          'open_date': openDate.toIso8601String(),
          'is_opened': capsule.isOpened,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('TimeCapsuleProvider.createCapsule Supabase error: $e');
        _createLocalCapsule(capsule);
      }
    } else {
      _createLocalCapsule(capsule);
    }
  }

  void _createLocalCapsule(TimeCapsule capsule) {
    _capsules.add(capsule);
    _capsules.sort((a, b) => a.openDate.compareTo(b.openDate));
    _persist();
  }

  Future<void> openCapsule(String id) async {
    final index = _capsules.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final capsule = _capsules[index];
    if (!capsule.canOpen) return;

    if (_coupleId != null) {
      try {
        await Supabase.instance.client
            .from('time_capsules')
            .update({'is_opened': true})
            .eq('id', id);
      } catch (e) {
        debugPrint('TimeCapsuleProvider.openCapsule Supabase error: $e');
        _openLocalCapsule(index, capsule);
      }
    } else {
      _openLocalCapsule(index, capsule);
    }
  }

  void _openLocalCapsule(int index, TimeCapsule capsule) {
    _capsules[index] = capsule.copyWith(isOpened: true);
    _persist();
  }

  Future<void> deleteCapsule(String id) async {
    if (_coupleId != null) {
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
    if (!_disposed) notifyListeners();
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

  @override
  void dispose() {
    _syncSub?.cancel();
    _disposed = true;
    super.dispose();
  }
}
