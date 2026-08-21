import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/features/bucket_list/bucket_list_state.dart';
import 'package:days_together/models/bucket_list_model.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/recent_activity_service.dart';

/// Riverpod port of `BucketListProvider` (Phase 6a of the architecture
/// migration, the first of the 12 domain providers -- the proof of the
/// `SupabaseLifecycleNotifier` pattern the other 11 follow). Behavior is a
/// line-for-line port of the original `ChangeNotifier`: same optimistic
/// local writes, same `_localMutations` self-echo suppression on the
/// realtime diff, same SharedPreferences cache shape (so existing cached
/// data on a real device still loads under the new provider) -- only the
/// state-holding mechanism (`state =` instead of `notifyListeners()`) and
/// session-lifecycle wiring (this mixin instead of `SupabaseLifecycleProvider`)
/// changed.
class BucketListController extends Notifier<BucketListState>
    with SupabaseLifecycleNotifier<BucketListState> {
  static const String _storageKey = 'bucket_list_items';
  final Set<String> _localMutations = {};

  @override
  String get tableName => 'bucket_list';

  @override
  BucketListState build() {
    initSessionLifecycle();
    _loadFromCache();
    return const BucketListState();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      List<BucketListItem> items = const [];
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        items = jsonList.map((json) => BucketListItem.fromJson(json)).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      }
      // build() returned before this completed -- if nothing is watching
      // this autoDispose provider by the time the awaited call above
      // resolves, Riverpod may have already torn it down, and `state =`
      // would throw. Every method below that touches `state` after an
      // `await` repeats this same guard.
      if (!ref.mounted) return;
      state = state.copyWith(items: items, isLoading: false);
    } catch (e, st) {
      debugPrint('BucketListController._loadFromCache failed: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  @override
  Future<void> purgeCache() async {
    state = state.copyWith(items: [], isLoading: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    try {
      final List<dynamic> res = await Supabase.instance.client
          .from('bucket_list')
          .select()
          .eq('couple_id', coupleId!);
      final parsed = res.map(_parseItem).toList()..sort((a, b) => a.order.compareTo(b.order));

      if (!ref.mounted) return;
      state = state.copyWith(items: parsed, isLoading: false);
      await _persistLocalOnly();
    } catch (e) {
      debugPrint('BucketListController.syncInitialData error: $e');
    }
  }

  BucketListItem _parseItem(dynamic data) {
    return BucketListItem(
      id: data['id'] as String,
      title: data['title'] ?? '',
      isCompleted: data['is_completed'] ?? false,
      completedAt: data['completed_at'] != null ? DateTime.parse(data['completed_at'] as String) : null,
      order: data['order_index'] ?? 0,
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'] as String) : DateTime.now(),
      scheduledAt: data['scheduled_at'] != null ? DateTime.parse(data['scheduled_at'] as String) : null,
    );
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    if (!ref.mounted) return;
    final incoming = dataList.map(_parseItem).toList()..sort((a, b) => a.order.compareTo(b.order));
    final wasLoading = state.isLoading;
    final oldItems = state.items;

    if (!wasLoading) {
      final added = incoming.where((inc) => !oldItems.any((old) => old.id == inc.id)).toList();
      for (final item in added) {
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

      final completed = incoming
          .where((inc) => inc.isCompleted && !oldItems.any((old) => old.id == inc.id && old.isCompleted))
          .toList();
      for (final item in completed) {
        final existedAndNotCompleted = oldItems.any((old) => old.id == item.id && !old.isCompleted);
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

      final deleted = oldItems.where((old) => !incoming.any((inc) => inc.id == old.id)).toList();
      for (final item in deleted) {
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

    state = state.copyWith(items: incoming, isLoading: false);
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('BucketListController: Supabase sync error: $error');
    _loadFromCache();
  }

  Future<void> addItem(String title, {DateTime? scheduledAt}) async {
    final item = BucketListItem(title: title, order: state.items.length, scheduledAt: scheduledAt);
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
        debugPrint('BucketListController.addItem Supabase error: $e');
        if (!ref.mounted) return;
        state = state.copyWith(items: [...state.items, item]);
        await _persist();
      }
    } else {
      state = state.copyWith(items: [...state.items, item]);
      await _persist();
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Bucket List item created',
      description: 'Added: "$title"',
      icon: '🪣',
      referenceId: item.id,
      route: 'bucket_list',
    );
  }

  Future<void> updateItem(String id, {String? title, DateTime? scheduledAt, bool clearDate = false}) async {
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
        await Supabase.instance.client.from('bucket_list').update(updates).eq('id', id);
        NotificationService().sendPartnerNotification(
          title: 'Bucket List Updated',
          body: '📝 Your partner updated the bucket list item:\n"${title ?? 'Item'}"',
          feature: 'bucket_list',
          itemId: id,
        );
      } catch (e) {
        debugPrint('BucketListController.updateItem Supabase error: $e');
      }
      if (!ref.mounted) return;
      _applyItemUpdate(id, title: title, scheduledAt: scheduledAt, clearDate: clearDate);
      await _persist();
    }

    if (!ref.mounted) return;
    final updatedItem = state.items.firstWhere(
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

  void _applyItemUpdate(String id, {String? title, DateTime? scheduledAt, bool clearDate = false}) {
    final index = state.items.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final items = [...state.items];
    items[index] = items[index].copyWith(
      title: title,
      scheduledAt: clearDate ? null : (scheduledAt ?? items[index].scheduledAt),
    );
    state = state.copyWith(items: items);
  }

  Future<void> toggleItem(String id) async {
    _localMutations.add(id);
    final index = state.items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = state.items[index];
      final newCompleted = !item.isCompleted;
      final newCompletedAt = newCompleted ? DateTime.now() : null;

      final items = [...state.items];
      items[index] = item.copyWith(isCompleted: newCompleted, completedAt: newCompletedAt);
      state = state.copyWith(items: items);

      if (coupleId != null) {
        try {
          await Supabase.instance.client
              .from('bucket_list')
              .update({'is_completed': newCompleted, 'completed_at': newCompletedAt?.toIso8601String()})
              .eq('id', id);
          if (newCompleted) {
            NotificationService().sendPartnerNotification(
              title: 'Bucket List Completed!',
              body: '🎉 Your partner completed a bucket list item:\n"${item.title}"',
              feature: 'bucket_list',
              itemId: id,
            );
          }
        } catch (e) {
          debugPrint('BucketListController.toggleItem Supabase error: $e');
        }
      }
      if (!ref.mounted) return;
      await _persist();
    }

    if (!ref.mounted) return;
    final updatedItem = state.items.firstWhere((i) => i.id == id);
    await RecentActivityService.instance.logActivity(
      activityType: updatedItem.isCompleted ? 'completed' : 'updated',
      title: updatedItem.isCompleted ? 'Bucket List item completed' : 'Bucket List item updated',
      description: updatedItem.isCompleted ? 'We did: "${updatedItem.title}" 🎉' : 'Marked active: "${updatedItem.title}"',
      icon: updatedItem.isCompleted ? '🎉' : '🪣',
      referenceId: id,
      route: 'bucket_list',
    );
  }

  Future<void> updateItemTitle(String id, String newTitle) async {
    _localMutations.add(id);
    final index = state.items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final items = [...state.items];
      items[index] = items[index].copyWith(title: newTitle);
      state = state.copyWith(items: items);

      if (coupleId != null) {
        try {
          await Supabase.instance.client.from('bucket_list').update({'title': newTitle}).eq('id', id);
        } catch (e) {
          debugPrint('BucketListController.updateItemTitle Supabase error: $e');
        }
      }
      if (!ref.mounted) return;
      await _persist();
    }
  }

  Future<void> deleteItem(String id) async {
    _localMutations.add(id);
    final index = state.items.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final itemToDelete = state.items[index];

    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('bucket_list').delete().eq('id', id);
        NotificationService().sendPartnerNotification(
          title: 'Bucket List Item Deleted',
          body: '🗑️ Your partner deleted a bucket list item.',
          feature: 'bucket_list',
          itemId: id,
        );

        final remaining = state.items.where((i) => i.id != id).toList();
        for (var i = 0; i < remaining.length; i++) {
          if (remaining[i].order != i) {
            await Supabase.instance.client.from('bucket_list').update({'order_index': i}).eq('id', remaining[i].id);
          }
          if (!ref.mounted) return;
        }
        state = state.copyWith(items: remaining);
      } catch (e) {
        debugPrint('BucketListController.deleteItem Supabase error: $e');
        if (!ref.mounted) return;
        final items = state.items.where((i) => i.id != id).toList();
        for (var i = 0; i < items.length; i++) {
          items[i] = items[i].copyWith(order: i);
        }
        state = state.copyWith(items: items);
        await _persist();
      }
    } else {
      final items = state.items.where((i) => i.id != id).toList();
      for (var i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(order: i);
      }
      state = state.copyWith(items: items);
      await _persist();
    }

    if (!ref.mounted) return;
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
    if (oldIndex < 0 || oldIndex >= state.items.length) return;
    if (oldIndex < newIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, state.items.length - 1);

    final items = [...state.items];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = state.copyWith(items: items);

    if (coupleId != null) {
      try {
        for (var i = 0; i < state.items.length; i++) {
          await Supabase.instance.client.from('bucket_list').update({'order_index': i}).eq('id', state.items[i].id);
          if (!ref.mounted) return;
        }
      } catch (e) {
        debugPrint('BucketListController.reorderItems Supabase error: $e');
        if (!ref.mounted) return;
        final reindexed = [for (var i = 0; i < state.items.length; i++) state.items[i].copyWith(order: i)];
        state = state.copyWith(items: reindexed);
        await _persist();
      }
    } else {
      final reindexed = [for (var i = 0; i < state.items.length; i++) state.items[i].copyWith(order: i)];
      state = state.copyWith(items: reindexed);
      await _persist();
    }
  }

  Future<void> _persist() => _persistLocalOnly();

  Future<void> _persistLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.items.map((item) => item.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('BucketListController._persistLocalOnly failed: $e\n$st');
    }
  }
}

final bucketListControllerProvider = NotifierProvider.autoDispose<BucketListController, BucketListState>(
  BucketListController.new,
  dependencies: [coupleSessionProvider],
);
