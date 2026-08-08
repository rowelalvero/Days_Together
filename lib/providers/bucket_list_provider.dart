import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/models/bucket_list_model.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/recent_activity_service.dart';

import 'package:days_together/services/relationship_lifecycle_manager.dart';

class BucketListProvider extends SupabaseLifecycleProvider {
  static const String _storageKey = 'bucket_list_items';
  List<BucketListItem> _items = [];
  bool _isLoading = true;
  final Set<String> _localMutations = {};

  List<BucketListItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  int get totalItems => _items.length;
  int get completedItems => _items.where((i) => i.isCompleted).length;
  double get progress => totalItems == 0 ? 0 : completedItems / totalItems;

  @override
  String get tableName => 'bucket_list';

  BucketListProvider() : super() {
    _loadItems();
  }

  @override
  Future<void> purgeCache() async {
    _items = [];
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
          .from('bucket_list')
          .select()
          .eq('couple_id', coupleId!);
      final parsed = res.map((data) {
        return BucketListItem(
          id: data['id'] as String,
          title: data['title'] ?? '',
          isCompleted: data['is_completed'] ?? false,
          completedAt: data['completed_at'] != null
              ? DateTime.parse(data['completed_at'] as String)
              : null,
          order: data['order_index'] ?? 0,
          createdAt: data['created_at'] != null
              ? DateTime.parse(data['created_at'] as String)
              : DateTime.now(),
          scheduledAt: data['scheduled_at'] != null
              ? DateTime.parse(data['scheduled_at'] as String)
              : null,
        );
      }).toList()..sort((a, b) => a.order.compareTo(b.order));

      _items = parsed;
      await _persistLocalOnly();
      if (!isDisposed) notifyListeners();
    } catch (e) {
      debugPrint('BucketListProvider.syncInitialData error: $e');
    }
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    final incoming = dataList.map((data) {
      return BucketListItem(
        id: data['id'] as String,
        title: data['title'] ?? '',
        isCompleted: data['is_completed'] ?? false,
        completedAt: data['completed_at'] != null
            ? DateTime.parse(data['completed_at'] as String)
            : null,
        order: data['order_index'] ?? 0,
        createdAt: data['created_at'] != null
            ? DateTime.parse(data['created_at'] as String)
            : DateTime.now(),
        scheduledAt: data['scheduled_at'] != null
            ? DateTime.parse(data['scheduled_at'] as String)
            : null,
      );
    }).toList();

    incoming.sort((a, b) => a.order.compareTo(b.order));

    if (!_isLoading) {
      // Detect additions
      final added = incoming
          .where((inc) => !_items.any((old) => old.id == inc.id))
          .toList();
      for (var item in added) {
        if (_localMutations.contains(item.id)) {
          _localMutations.remove(item.id);
          continue;
        }
        RecentActivityService.instance.logActivity(
          activityType: 'created',
          title: "Partner's bucket list item added",
          description: 'Added: "${item.title}"',
          icon: '🪣',
          referenceId: item.id,
          route: 'bucket_list',
        );
      }

      // Detect completions
      final completed = incoming
          .where(
            (inc) =>
                inc.isCompleted &&
                !_items.any((old) => old.id == inc.id && old.isCompleted),
          )
          .toList();
      for (var item in completed) {
        final existedAndNotCompleted = _items.any(
          (old) => old.id == item.id && !old.isCompleted,
        );
        if (existedAndNotCompleted) {
          if (_localMutations.contains(item.id)) {
            _localMutations.remove(item.id);
            continue;
          }
          RecentActivityService.instance.logActivity(
            activityType: 'completed',
            title: "Partner's bucket list item completed",
            description: 'We did: "${item.title}" 🎉',
            icon: '🎉',
            referenceId: item.id,
            route: 'bucket_list',
          );
        }
      }

      // Detect deletions
      final deleted = _items
          .where((old) => !incoming.any((inc) => inc.id == old.id))
          .toList();
      for (var item in deleted) {
        if (_localMutations.contains(item.id)) {
          _localMutations.remove(item.id);
          continue;
        }
        RecentActivityService.instance.logActivity(
          activityType: 'deleted',
          title: "Partner's bucket list item deleted",
          description: 'Deleted: "${item.title}"',
          icon: '🗑️',
          referenceId: item.id,
          route: 'bucket_list',
        );
      }
    }

    _items = incoming;
    _isLoading = false;
    if (!isDisposed) notifyListeners();
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('BucketListProvider: Supabase sync error: $error');
    _loadItems();
  }

  Future<void> _loadItems() async {
    _isLoading = true;
    if (!isDisposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _items = jsonList.map((json) => BucketListItem.fromJson(json)).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      } else {
        _items = [];
      }
    } catch (e, st) {
      debugPrint('BucketListProvider._loadItems failed: $e\n$st');
    } finally {
      _isLoading = false;
      if (!isDisposed) notifyListeners();
    }
  }

  Future<void> addItem(String title, {DateTime? scheduledAt}) async {
    final item = BucketListItem(
      title: title,
      order: _items.length,
      scheduledAt: scheduledAt,
    );
    _localMutations.add(item.id);

    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('bucket_list').upsert({
          'id': item.id,
          'couple_id': coupleId,
          'title': item.title,
          'is_completed': item.isCompleted,
          'completed_at': item.completedAt?.toIso8601String(),
          'order_index': item.order,
          'created_at': item.createdAt.toIso8601String(),
          'scheduled_at': item.scheduledAt?.toIso8601String(),
        });
        NotificationService().sendPartnerNotification(
          title: 'New Bucket List Idea',
          body: '❤️ Your partner added a new bucket list idea:\n"$title"',
          feature: 'bucket_list',
          itemId: item.id,
        );
      } catch (e) {
        debugPrint('BucketListProvider.addItem Supabase error: $e');
        _items.add(item);
        await _persist();
      }
    } else {
      _items.add(item);
      await _persist();
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Bucket List item created',
      description: 'Added: "$title"',
      icon: '🪣',
      referenceId: item.id,
      route: 'bucket_list',
    );
  }

  Future<void> updateItem(
    String id, {
    String? title,
    DateTime? scheduledAt,
    bool clearDate = false,
  }) async {
    _localMutations.add(id);
    if (coupleId != null) {
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
        NotificationService().sendPartnerNotification(
          title: 'Bucket List Updated',
          body:
              '📝 Your partner updated the bucket list item:\n"${title ?? 'Item'}"',
          feature: 'bucket_list',
          itemId: id,
        );
      } catch (e) {
        debugPrint('BucketListProvider.updateItem Supabase error: $e');
        final index = _items.indexWhere((i) => i.id == id);
        if (index != -1) {
          _items[index] = _items[index].copyWith(
            title: title,
            scheduledAt: clearDate
                ? null
                : (scheduledAt ?? _items[index].scheduledAt),
          );
          await _persist();
        }
      }
      final index = _items.indexWhere((i) => i.id == id);
      if (index == -1) return;
      _items[index] = _items[index].copyWith(
        title: title,
        scheduledAt: clearDate
            ? null
            : (scheduledAt ?? _items[index].scheduledAt),
      );
      await _persist();
    }

    final updatedItem = _items.firstWhere(
      (i) => i.id == id,
      orElse: () => BucketListItem(title: title ?? '', order: 0),
    );
    await RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: 'Bucket List item updated',
      description: 'Updated: "${title ?? updatedItem.title}"',
      icon: '✏️',
      referenceId: id,
      route: 'bucket_list',
    );
  }

  Future<void> toggleItem(String id) async {
    _localMutations.add(id);
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _items[index];
      final newCompleted = !item.isCompleted;
      final newCompletedAt = newCompleted ? DateTime.now() : null;

      _items[index] = item.copyWith(
        isCompleted: newCompleted,
        completedAt: newCompletedAt,
      );
      notifyListeners();

      if (coupleId != null) {
        try {
          await Supabase.instance.client
              .from('bucket_list')
              .update({
                'is_completed': newCompleted,
                'completed_at': newCompletedAt?.toIso8601String(),
              })
              .eq('id', id);
          if (newCompleted) {
            NotificationService().sendPartnerNotification(
              title: 'Bucket List Completed!',
              body:
                  '🎉 Your partner completed a bucket list item:\n"${item.title}"',
              feature: 'bucket_list',
              itemId: id,
            );
          }
        } catch (e) {
          debugPrint('BucketListProvider.toggleItem Supabase error: $e');
        }
      }
      await _persist();
    }

    final updatedItem = _items.firstWhere((i) => i.id == id);
    await RecentActivityService.instance.logActivity(
      activityType: updatedItem.isCompleted ? 'completed' : 'updated',
      title: updatedItem.isCompleted
          ? 'Bucket List item completed'
          : 'Bucket List item updated',
      description: updatedItem.isCompleted
          ? 'We did: "${updatedItem.title}" 🎉'
          : 'Marked active: "${updatedItem.title}"',
      icon: updatedItem.isCompleted ? '🎉' : '🪣',
      referenceId: id,
      route: 'bucket_list',
    );
  }

  Future<void> updateItemTitle(String id, String newTitle) async {
    _localMutations.add(id);
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index] = _items[index].copyWith(title: newTitle);
      notifyListeners();

      if (coupleId != null) {
        try {
          await Supabase.instance.client
              .from('bucket_list')
              .update({'title': newTitle})
              .eq('id', id);
        } catch (e) {
          debugPrint('BucketListProvider.updateItemTitle Supabase error: $e');
        }
      }
      await _persist();
    }
  }

  Future<void> deleteItem(String id) async {
    _localMutations.add(id);
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final itemToDelete = _items[index];

    if (coupleId != null) {
      try {
        await Supabase.instance.client
            .from('bucket_list')
            .delete()
            .eq('id', id);
        NotificationService().sendPartnerNotification(
          title: 'Bucket List Item Deleted',
          body: '🗑️ Your partner deleted a bucket list item.',
          feature: 'bucket_list',
          itemId: id,
        );

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

    await RecentActivityService.instance.logActivity(
      activityType: 'deleted',
      title: 'Bucket List item deleted',
      description: 'Deleted: "${itemToDelete.title}"',
      icon: '🗑️',
      referenceId: id,
      route: 'bucket_list',
    );
  }

  Future<void> reorderItems(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    if (oldIndex < newIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, _items.length - 1);

    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);

    if (coupleId != null) {
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
    if (!isDisposed) notifyListeners();
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
}
