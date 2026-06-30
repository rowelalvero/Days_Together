import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/services/supabase_sync_service.dart';
import 'package:days_together/models/bucket_list_model.dart';
import 'package:days_together/providers/relationship_provider.dart';

class BucketListProvider with ChangeNotifier {
  static const String _storageKey = 'bucket_list_items';
  List<BucketListItem> _items = [];
  bool _isLoading = true;
  bool _disposed = false;

  String? _coupleId;
  String? _userId;
  StreamSubscription? _syncSub;

  List<BucketListItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  int get totalItems => _items.length;
  int get completedItems => _items.where((i) => i.isCompleted).length;
  double get progress => totalItems == 0 ? 0 : completedItems / totalItems;

  BucketListProvider() {
    _loadItems();
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
        _loadItems();
      }
    }
  }

  void _initSupabaseSync() {
    if (_coupleId == null) return;
    _isLoading = true;
    if (!_disposed) notifyListeners();

    _syncSub = SupabaseSyncService.instance.subscribeToCoupleData(
      tableName: 'bucket_list',
      coupleId: _coupleId!,
      onData: (dataList) {
      _items = dataList.map((data) {
        return BucketListItem(
          id: data['id'] as String,
          title: data['title'] ?? '',
          isCompleted: data['is_completed'] ?? false,
          completedAt: data['completed_at'] != null ? DateTime.parse(data['completed_at'] as String) : null,
          order: data['order_index'] ?? 0,
          createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'] as String) : DateTime.now(),
          scheduledAt: data['scheduled_at'] != null ? DateTime.parse(data['scheduled_at'] as String) : null,
        );
      }).toList();

      _items.sort((a, b) => a.order.compareTo(b.order));
      _isLoading = false;
      if (!_disposed) notifyListeners();

      _persistLocalOnly();
      },
      onError: (err) {
        debugPrint('BucketListProvider: Supabase sync error: $err');
        _loadItems();
      },
    );
  }

  Future<void> _loadItems() async {
    _isLoading = true;
    if (!_disposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _items = jsonList
            .map((json) => BucketListItem.fromJson(json))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      } else {
        _items = [];
      }
    } catch (e, st) {
      debugPrint('BucketListProvider._loadItems failed: $e\n$st');
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> addItem(String title, {DateTime? scheduledAt}) async {
    final item = BucketListItem(
      title: title,
      order: _items.length,
      scheduledAt: scheduledAt,
    );

    if (_coupleId != null) {
      try {
        await Supabase.instance.client
            .from('bucket_list')
            .upsert({
          'id': item.id,
          'couple_id': _coupleId,
          'title': item.title,
          'is_completed': item.isCompleted,
          'completed_at': item.completedAt?.toIso8601String(),
          'order_index': item.order,
          'created_at': item.createdAt.toIso8601String(),
          'scheduled_at': item.scheduledAt?.toIso8601String(),
        });
      } catch (e) {
        debugPrint('BucketListProvider.addItem Supabase error: $e');
        _items.add(item);
        await _persist();
      }
    } else {
      _items.add(item);
      await _persist();
    }
  }

  Future<void> updateItem(String id, {String? title, DateTime? scheduledAt, bool clearDate = false}) async {
    if (_coupleId != null) {
      try {
        final updates = <String, dynamic>{};
        if (title != null) updates['title'] = title;
        if (clearDate) {
          updates['scheduled_at'] = null;
        } else if (scheduledAt != null) {
          updates['scheduled_at'] = scheduledAt.toIso8601String();
        }
        await Supabase.instance.client
            .from('bucket_list')
            .update(updates)
            .eq('id', id);
      } catch (e) {
        debugPrint('BucketListProvider.updateItem Supabase error: $e');
        final index = _items.indexWhere((i) => i.id == id);
        if (index != -1) {
          _items[index] = _items[index].copyWith(
            title: title,
            scheduledAt: clearDate ? null : (scheduledAt ?? _items[index].scheduledAt),
          );
          await _persist();
        }
      }
    } else {
      final index = _items.indexWhere((i) => i.id == id);
      if (index == -1) return;
      _items[index] = _items[index].copyWith(
        title: title,
        scheduledAt: clearDate ? null : (scheduledAt ?? _items[index].scheduledAt),
      );
      await _persist();
    }
  }

  Future<void> toggleItem(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final item = _items[index];
    final nextCompleted = !item.isCompleted;
    final nextCompletedAt = nextCompleted ? DateTime.now() : null;

    if (_coupleId != null) {
      try {
        await Supabase.instance.client
            .from('bucket_list')
            .update({
          'is_completed': nextCompleted,
          'completed_at': nextCompletedAt?.toIso8601String(),
        }).eq('id', id);
      } catch (e) {
        debugPrint('BucketListProvider.toggleItem Supabase error: $e');
        _items[index] = item.copyWith(
          isCompleted: nextCompleted,
          completedAt: nextCompletedAt,
        );
        await _persist();
      }
    } else {
      _items[index] = item.copyWith(
        isCompleted: nextCompleted,
        completedAt: nextCompletedAt,
      );
      await _persist();
    }
  }

  Future<void> deleteItem(String id) async {
    if (_coupleId != null) {
      try {
        await Supabase.instance.client
            .from('bucket_list')
            .delete()
            .eq('id', id);

        final remaining = _items.where((i) => i.id != id).toList();
        for (var i = 0; i < remaining.length; i++) {
          if (remaining[i].order != i) {
            await Supabase.instance.client
                .from('bucket_list')
                .update({'order_index': i})
                .eq('id', remaining[i].id);
          }
        }
      } catch (e) {
        debugPrint('BucketListProvider.deleteItem Supabase error: $e');
        _items.removeWhere((i) => i.id == id);
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].copyWith(order: i);
        }
        await _persist();
      }
    } else {
      _items.removeWhere((i) => i.id == id);
      for (var i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(order: i);
      }
      await _persist();
    }
  }

  Future<void> reorderItems(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    if (oldIndex < newIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, _items.length - 1);

    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);

    if (_coupleId != null) {
      try {
        for (var i = 0; i < _items.length; i++) {
          await Supabase.instance.client
              .from('bucket_list')
              .update({'order_index': i})
              .eq('id', _items[i].id);
        }
      } catch (e) {
        debugPrint('BucketListProvider.reorderItems Supabase error: $e');
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].copyWith(order: i);
        }
        await _persist();
      }
    } else {
      for (var i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(order: i);
      }
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
      final jsonList = _items.map((item) => item.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('BucketListProvider._persistLocalOnly failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _disposed = true;
    super.dispose();
  }
}
