import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/features/timeline/timeline_state.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/services/local_persistence_service.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/permission_service.dart';
import 'package:days_together/services/recent_activity_service.dart';
import 'package:days_together/services/storage_url_service.dart';

/// Riverpod port of `TimelineProvider` (Phase 6a of the architecture
/// migration -- the widest UI consumer surface of the 12, 18 files).
/// Faithful behavior port, including its one deliberate asymmetry:
/// [addTimelineItem]/[updateTimelineItem] do not apply locally on the
/// Supabase success path (rely on the realtime echo, like
/// `GiftReminderController`/`CalendarController`/`TimeCapsuleController`),
/// but [deleteTimelineItem] always applies immediately and optimistically,
/// paired or not, guarding against the realtime stream resurrecting a
/// just-deleted item via `_locallyDeletedIds` -- exactly as the original
/// does, for the same reason (instant delete feedback matters more than a
/// round-trip).
class TimelineController extends Notifier<TimelineState> with SupabaseLifecycleNotifier<TimelineState> {
  final LocalPersistenceService _repository = LocalPersistenceService();
  final ImagePicker _picker = ImagePicker();
  final Set<String> _locallyDeletedIds = {};
  final Set<String> _localMutations = {};

  @override
  String get tableName => 'timeline_items';

  @override
  TimelineState build() {
    initSessionLifecycle();
    _loadSortOrder().then((_) => _loadFromCache());
    return const TimelineState();
  }

  Future<void> _loadSortOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAscending = prefs.getBool(PrefsKeys.timelineIsAscending) ?? true;
      if (!ref.mounted) return;
      state = state.copyWith(isAscending: isAscending);
    } catch (_) {}
  }

  List<TimelineItemData> _sorted(List<TimelineItemData> items, bool ascending) {
    final sorted = List<TimelineItemData>.from(items)
      ..sort((a, b) => ascending ? a.date.compareTo(b.date) : b.date.compareTo(a.date));
    for (var i = 0; i < sorted.length; i++) {
      sorted[i] = sorted[i].copyWith(position: i);
    }
    return sorted;
  }

  Future<void> toggleSortOrder() async {
    final oldItem = state.items.isNotEmpty && state.currentScrubIndex < state.items.length
        ? state.items[state.currentScrubIndex]
        : null;
    final nextAscending = !state.isAscending;
    final resorted = _sorted(state.items, nextAscending);

    var newIndex = state.currentScrubIndex;
    if (oldItem != null) {
      final found = resorted.indexWhere((item) => item.id == oldItem.id);
      if (found != -1) newIndex = found;
    }

    state = state.copyWith(
      isAscending: nextAscending,
      items: resorted,
      currentScrubIndex: TimelineState.clampIndex(resorted, newIndex),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrefsKeys.timelineIsAscending, nextAscending);
    } catch (_) {}
    await _persistLocalOnly();
  }

  @override
  Future<void> purgeCache() async {
    state = state.copyWith(items: [], isLoading: false);
    try {
      await _repository.saveTimelineItems([]);
    } catch (_) {}
  }

  TimelineItemData _parseItem(Map<String, dynamic> data) {
    final rawComments = data['comments'];
    List<CommentData> parsedComments = [];
    if (rawComments != null) {
      if (rawComments is List) {
        parsedComments = rawComments.map((c) => CommentData.fromJson(c as Map<String, dynamic>)).toList();
      } else if (rawComments is String) {
        try {
          final decoded = jsonDecode(rawComments);
          if (decoded is List) {
            parsedComments = decoded.map((c) => CommentData.fromJson(c as Map<String, dynamic>)).toList();
          }
        } catch (_) {}
      }
    }
    return TimelineItemData(
      id: data['id'] as String,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] as String?,
      imagePath: data['image_path'] as String?,
      networkImageUrl: data['network_image_url'] as String?,
      date: data['date'] != null ? DateTime.parse(data['date'] as String).toLocal() : DateTime.now(),
      isImageCard: data['is_image_card'] ?? false,
      position: data['position'] ?? 0,
      mood: data['mood'] ?? '😍',
      photoUrls: List<String>.from(data['photo_urls'] ?? []),
      isPinned: data['is_pinned'] ?? false,
      comments: parsedComments,
    );
  }

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    try {
      final List<dynamic> res = await Supabase.instance.client
          .from('timeline_items')
          .select()
          .eq('couple_id', coupleId!)
          .order('date', ascending: false)
          .limit(100);
      if (!ref.mounted) return;
      final parsed = _sorted(res.map((data) => _parseItem(data)).toList(), state.isAscending);

      state = state.copyWith(items: parsed, isLoading: false);
      await _repository.saveTimelineItems(state.items);
    } catch (e) {
      debugPrint('TimelineController.syncInitialData error: $e');
    }
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    if (!ref.mounted) return;
    // Filter out locally deleted items to handle stream filter/delete timing issues.
    final activeDataList = dataList.where((data) => !_locallyDeletedIds.contains(data['id'] as String)).toList();
    final incoming = _sorted(activeDataList.map((data) => _parseItem(data)).toList(), state.isAscending);
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
          title: 'Partner added a memory 📸',
          description: 'Added: "${item.title}"',
          icon: '📸',
          referenceId: item.id,
          route: 'timeline',
        );
      }

      for (final inc in incoming) {
        final matchIndex = oldItems.indexWhere((old) => old.id == inc.id);
        final match = matchIndex != -1 ? oldItems[matchIndex] : null;
        if (match != null &&
            (match.title != inc.title ||
                match.description != inc.description ||
                match.date != inc.date ||
                match.networkImageUrl != inc.networkImageUrl)) {
          if (_localMutations.contains(inc.id)) {
            _localMutations.remove(inc.id);
            continue;
          }
          RecentActivityService.instance.logActivity(
            activityType: 'updated',
            title: 'Partner updated a memory ✏️',
            description: 'Updated: "${inc.title}"',
            icon: '✏️',
            referenceId: inc.id,
            route: 'timeline',
          );
        }
      }

      final deleted = oldItems
          .where((old) => !incoming.any((inc) => inc.id == old.id) && !_locallyDeletedIds.contains(old.id))
          .toList();
      for (final item in deleted) {
        if (_localMutations.contains(item.id)) {
          _localMutations.remove(item.id);
          continue;
        }
        RecentActivityService.instance.logActivity(
          activityType: 'deleted',
          title: 'Partner deleted a memory 🗑️',
          description: 'Deleted: "${item.title}"',
          icon: '🗑️',
          referenceId: item.id,
          route: 'timeline',
        );
      }
    }

    state = state.copyWith(
      items: incoming,
      isLoading: false,
      currentScrubIndex: TimelineState.clampIndex(incoming, state.currentScrubIndex),
    );
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('TimelineController: Supabase sync error: $error');
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    try {
      final loaded = await _repository.loadTimelineItems();
      if (!ref.mounted) return;
      final sorted = _sorted(loaded, state.isAscending);
      state = state.copyWith(
        items: sorted,
        isLoading: false,
        currentScrubIndex: TimelineState.clampIndex(sorted, state.currentScrubIndex),
      );
    } catch (e, st) {
      debugPrint('TimelineController._loadFromCache failed: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(items: [], isLoading: false);
    }
  }

  Future<void> addTimelineItem(TimelineItemData item) async {
    _localMutations.add(item.id);
    if (coupleId != null) {
      try {
        // Stores the storage PATH, not a URL: the bucket is private, so images
        // are rendered through StorageImage, which signs the path on demand.
        String? imageRef;
        if (item.imagePath != null) {
          final file = File(item.imagePath!);
          if (await file.exists()) {
            final storagePath = 'couples/$coupleId/timeline/${item.id}.jpg';
            await Supabase.instance.client.storage
                .from(StorageBuckets.timeline)
                .upload(storagePath, file, fileOptions: const FileOptions(upsert: true));
            imageRef = storagePath;
          }
        }

        final sortedList = List<TimelineItemData>.from(state.items)..add(item);
        sortedList.sort(
          (a, b) => state.isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
        );
        final calculatedPosition = sortedList.indexOf(item);

        final Map<String, dynamic> dbData = {
          'id': item.id,
          'couple_id': coupleId,
          'title': item.title,
          'description': item.description,
          'location': item.location,
          'image_path': item.imagePath,
          'network_image_url': imageRef ?? item.networkImageUrl,
          'date': item.date.toUtc().toIso8601String(),
          'is_image_card': item.isImageCard,
          'position': calculatedPosition,
          'mood': item.mood,
          'photo_urls': item.photoUrls,
          'is_pinned': item.isPinned,
          'comments': item.comments.map((c) => c.toJson()).toList(),
        };

        try {
          await Supabase.instance.client.from('timeline_items').upsert(dbData);
        } catch (e) {
          if (_isMissingCommentsColumn(e)) {
            final fallbackData = Map<String, dynamic>.from(dbData)..remove('comments');
            await Supabase.instance.client.from('timeline_items').upsert(fallbackData);
          } else {
            rethrow;
          }
        }

        try {
          await NotificationService().sendPartnerNotification(
            title: 'New Memory Shared 📸',
            body: 'A new memory was added: ${item.title}',
            feature: 'timeline',
            itemId: item.id,
          );
        } catch (fcmError) {
          debugPrint('TimelineController: Failed to trigger push notification: $fcmError');
        }
        // No local apply on success, matching the original: relies on the
        // realtime echo.
      } catch (e) {
        debugPrint('TimelineController.addTimelineItem Supabase error: $e');
        if (!ref.mounted) return;
        final resorted = _sorted([...state.items, item], state.isAscending);
        state = state.copyWith(
          items: resorted,
          currentScrubIndex: TimelineState.clampIndex(resorted, state.currentScrubIndex),
        );
        await _persist();
      }
    } else {
      final resorted = _sorted([...state.items, item], state.isAscending);
      state = state.copyWith(
        items: resorted,
        currentScrubIndex: TimelineState.clampIndex(resorted, state.currentScrubIndex),
      );
      await _persist();
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Memory added 📸',
      description: 'Added: "${item.title}"',
      icon: '📸',
      referenceId: item.id,
      route: 'timeline',
    );
  }

  bool _isMissingCommentsColumn(Object e) {
    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('comments') &&
        (errorStr.contains('column') ||
            errorStr.contains('pgrst204') ||
            errorStr.contains('does not exist') ||
            errorStr.contains('not found'));
  }

  Future<void> updateTimelineItem(String id, TimelineItemData updatedItem) async {
    _localMutations.add(id);
    final index = state.items.indexWhere((item) => item.id == id);
    if (index == -1) {
      debugPrint('TimelineController.updateTimelineItem: id $id not found');
      return;
    }

    if (coupleId != null) {
      try {
        String? imageRef = updatedItem.networkImageUrl;
        if (updatedItem.imagePath != null && updatedItem.imagePath != state.items[index].imagePath) {
          final file = File(updatedItem.imagePath!);
          if (await file.exists()) {
            final storagePath = 'couples/$coupleId/timeline/${updatedItem.id}.jpg';
            await Supabase.instance.client.storage
                .from(StorageBuckets.timeline)
                .upload(storagePath, file, fileOptions: const FileOptions(upsert: true));
            imageRef = storagePath;
            // The object is overwritten in place (same path, upsert), so any
            // signed URL and cached bytes for it are now stale.
            await StorageUrlService.instance.evict(bucket: StorageBuckets.timeline, ref: storagePath);
            await CachedNetworkImage.evictFromCache(
              StorageUrlService.cacheKeyFor(bucket: StorageBuckets.timeline, ref: storagePath),
            );
          }
        }

        final sortedList = List<TimelineItemData>.from(state.items);
        final idx = sortedList.indexWhere((item) => item.id == updatedItem.id);
        if (idx != -1) {
          sortedList[idx] = updatedItem;
        } else {
          sortedList.add(updatedItem);
        }
        sortedList.sort(
          (a, b) => state.isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
        );
        final calculatedPosition = sortedList.indexOf(updatedItem);

        final Map<String, dynamic> dbData = {
          'id': updatedItem.id,
          'couple_id': coupleId,
          'title': updatedItem.title,
          'description': updatedItem.description,
          'location': updatedItem.location,
          'image_path': updatedItem.imagePath,
          'network_image_url': imageRef,
          'date': updatedItem.date.toUtc().toIso8601String(),
          'is_image_card': updatedItem.isImageCard,
          'position': calculatedPosition,
          'mood': updatedItem.mood,
          'photo_urls': updatedItem.photoUrls,
          'is_pinned': updatedItem.isPinned,
          'comments': updatedItem.comments.map((c) => c.toJson()).toList(),
        };

        try {
          await Supabase.instance.client.from('timeline_items').upsert(dbData);
        } catch (e) {
          if (_isMissingCommentsColumn(e)) {
            final fallbackData = Map<String, dynamic>.from(dbData)..remove('comments');
            await Supabase.instance.client.from('timeline_items').upsert(fallbackData);
          } else {
            rethrow;
          }
        }
        // No local apply on success, matching the original.
      } catch (e) {
        debugPrint('TimelineController.updateTimelineItem Supabase error: $e');
        if (!ref.mounted) return;
        _applyLocalUpdate(id, updatedItem);
        await _persist();
      }
    } else {
      _applyLocalUpdate(id, updatedItem);
      await _persist();
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: 'Memory updated ✏️',
      description: 'Updated: "${updatedItem.title}"',
      icon: '✏️',
      referenceId: id,
      route: 'timeline',
    );
  }

  void _applyLocalUpdate(String id, TimelineItemData updatedItem) {
    final index = state.items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final items = [...state.items];
    items[index] = updatedItem;
    final resorted = _sorted(items, state.isAscending);
    state = state.copyWith(
      items: resorted,
      currentScrubIndex: TimelineState.clampIndex(resorted, state.currentScrubIndex),
    );
  }

  Future<void> deleteTimelineItem(String id) async {
    _localMutations.add(id);
    final index = state.items.indexWhere((item) => item.id == id);
    if (index == -1) {
      debugPrint('TimelineController.deleteTimelineItem: id $id not found');
      return;
    }

    // Add to locally deleted set to prevent stream updates from bringing it back.
    _locallyDeletedIds.add(id);

    final item = state.items[index];
    if (item.imagePath != null) {
      try {
        await _repository.deleteImage(item.imagePath!);
      } catch (e, st) {
        debugPrint('Failed to delete image ${item.imagePath}: $e\n$st');
      }
    }

    // Update local state first for immediate UI response, matching the
    // original -- delete is always optimistic-local, paired or not, unlike
    // add/update.
    if (!ref.mounted) return;
    final remaining = [...state.items]..removeAt(index);
    for (var i = 0; i < remaining.length; i++) {
      remaining[i] = remaining[i].copyWith(position: i);
    }
    state = state.copyWith(
      items: remaining,
      currentScrubIndex: TimelineState.clampIndex(remaining, state.currentScrubIndex),
    );
    await _persist();

    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('timeline_items').delete().eq('id', id);

        try {
          final storagePath = 'couples/$coupleId/timeline/$id.jpg';
          await Supabase.instance.client.storage.from('timeline').remove([storagePath]);
        } catch (_) {}

        final currentRemaining = List<TimelineItemData>.from(state.items);
        for (var i = 0; i < currentRemaining.length; i++) {
          await Supabase.instance.client.from('timeline_items').update({'position': i}).eq('id', currentRemaining[i].id);
          if (!ref.mounted) return;
        }
      } catch (e) {
        debugPrint('TimelineController.deleteTimelineItem Supabase error: $e');
      }
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'deleted',
      title: 'Memory deleted 🗑️',
      description: 'Deleted: "${item.title}"',
      icon: '🗑️',
      referenceId: id,
      route: 'timeline',
    );
  }

  Future<void> reorderTimelineItems(int oldIndex, int newIndex) async {
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
          await Supabase.instance.client.from('timeline_items').update({'position': i}).eq('id', state.items[i].id);
          if (!ref.mounted) return;
        }
        state = state.copyWith(currentScrubIndex: TimelineState.clampIndex(state.items, state.currentScrubIndex));
      } catch (e) {
        debugPrint('TimelineController.reorderTimelineItems Supabase error: $e');
        if (!ref.mounted) return;
        final reindexed = [for (var i = 0; i < state.items.length; i++) state.items[i].copyWith(position: i)];
        state = state.copyWith(
          items: reindexed,
          currentScrubIndex: TimelineState.clampIndex(reindexed, state.currentScrubIndex),
        );
        await _persist();
      }
    } else {
      final reindexed = [for (var i = 0; i < state.items.length; i++) state.items[i].copyWith(position: i)];
      state = state.copyWith(
        items: reindexed,
        currentScrubIndex: TimelineState.clampIndex(reindexed, state.currentScrubIndex),
      );
      await _persist();
    }
  }

  void setCurrentScrubIndex(int index) {
    state = state.copyWith(currentScrubIndex: TimelineState.clampIndex(state.items, index));
  }

  Future<String?> pickImage(BuildContext context) async {
    final hasPermission = await PermissionService().requestPhotosPermission(context);
    if (!hasPermission) return null;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (picked == null) return null;
      final source = File(picked.path);
      if (!await source.exists()) {
        debugPrint('TimelineController.pickImage: source file missing');
        return null;
      }
      return await _repository.saveImageToStorage(source);
    } catch (e, st) {
      debugPrint('TimelineController.pickImage failed: $e\n$st');
      return null;
    }
  }

  Future<void> _persist() async {
    await _persistLocalOnly();
  }

  Future<void> _persistLocalOnly() async {
    try {
      await _repository.saveTimelineItems(state.items);
    } catch (e, st) {
      debugPrint('TimelineController._persistLocalOnly failed: $e\n$st');
    }
  }

  Future<void> addCommentToItem(String itemId, String content, String authorName) async {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final updatedComments = List<CommentData>.from(state.items[index].comments)
      ..add(CommentData(authorName: authorName, content: content, date: DateTime.now()));

    final updatedItem = state.items[index].copyWith(comments: updatedComments);
    await updateTimelineItem(itemId, updatedItem);

    if (coupleId != null) {
      try {
        await NotificationService().sendPartnerNotification(
          title: 'New Comment on Memory 💬',
          body: '$authorName commented: "$content"',
          feature: 'timeline',
          itemId: itemId,
        );
      } catch (e) {
        debugPrint('TimelineController: Failed to send comment notification: $e');
      }
    }
  }

  Future<void> deleteCommentFromItem(String itemId, String commentId) async {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final updatedComments = state.items[index].comments.where((c) => c.id != commentId).toList();
    final updatedItem = state.items[index].copyWith(comments: updatedComments);
    await updateTimelineItem(itemId, updatedItem);
  }

  Future<void> togglePinComment(String itemId, String commentId) async {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final updatedComments = state.items[index].comments.map((c) {
      return c.id == commentId ? c.copyWith(isPinned: !c.isPinned) : c;
    }).toList();
    final updatedItem = state.items[index].copyWith(comments: updatedComments);
    await updateTimelineItem(itemId, updatedItem);
  }
}

final timelineControllerProvider = NotifierProvider.autoDispose<TimelineController, TimelineState>(
  TimelineController.new,
  dependencies: [coupleSessionProvider],
);
