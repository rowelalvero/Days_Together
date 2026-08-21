import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/services/local_persistence_service.dart';
import 'package:days_together/services/permission_service.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/services/recent_activity_service.dart';

import 'package:days_together/services/relationship_lifecycle_manager.dart';
import 'package:days_together/services/storage_url_service.dart';

class TimelineProvider extends SupabaseLifecycleProvider {
  final LocalPersistenceService _repository = LocalPersistenceService();
  final ImagePicker _picker = ImagePicker();
  List<TimelineItemData> _timelineItems = [];
  bool _isLoading = true;
  bool _isAscending = true;
  int _currentScrubIndex = 0;

  // Track locally deleted items to prevent them from re-appearing from the Supabase stream
  final Set<String> _locallyDeletedIds = {};
  final Set<String> _localMutations = {};

  bool get isAscending => _isAscending;
  int get currentScrubIndex => _currentScrubIndex;

  void setCurrentScrubIndex(int index, {bool notify = true}) {
    if (_timelineItems.isEmpty) {
      _currentScrubIndex = 0;
    } else {
      _currentScrubIndex = index.clamp(0, _timelineItems.length - 1);
    }
    if (notify && !isDisposed) {
      notifyListeners();
    }
  }

  void _clampCurrentScrubIndex({bool notify = false}) {
    if (_timelineItems.isEmpty) {
      _currentScrubIndex = 0;
    } else {
      _currentScrubIndex = _currentScrubIndex.clamp(
        0,
        _timelineItems.length - 1,
      );
    }
    if (notify && !isDisposed) {
      notifyListeners();
    }
  }

  List<TimelineItemData> get timelineItems => List.unmodifiable(_timelineItems);
  bool get isLoading => _isLoading;

  @override
  String get tableName => 'timeline_items';

  TimelineProvider() : super() {
    _loadSortOrder().then((_) => _loadTimeline());
  }

  Future<void> _loadSortOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAscending = prefs.getBool('timeline_is_ascending') ?? true;
    } catch (_) {}
  }

  Future<void> toggleSortOrder() async {
    final oldItem =
        _timelineItems.isNotEmpty && _currentScrubIndex < _timelineItems.length
        ? _timelineItems[_currentScrubIndex]
        : null;
    _isAscending = !_isAscending;
    _timelineItems.sort(
      (a, b) =>
          _isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
    );
    for (var i = 0; i < _timelineItems.length; i++) {
      _timelineItems[i] = _timelineItems[i].copyWith(position: i);
    }
    if (oldItem != null) {
      final newIndex = _timelineItems.indexWhere(
        (item) => item.id == oldItem.id,
      );
      if (newIndex != -1) {
        _currentScrubIndex = newIndex;
      }
    }
    _clampCurrentScrubIndex();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('timeline_is_ascending', _isAscending);
    } catch (_) {}
    await _persistLocalOnly();
  }

  @override
  Future<void> purgeCache() async {
    _timelineItems = [];
    try {
      await _repository.saveTimelineItems([]);
    } catch (_) {}
    if (!isDisposed) notifyListeners();
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
      final parsed = res.map((data) {
        final rawComments = data['comments'];
        List<CommentData> parsedComments = [];
        if (rawComments != null) {
          if (rawComments is List) {
            parsedComments = rawComments
                .map((c) => CommentData.fromJson(c as Map<String, dynamic>))
                .toList();
          } else if (rawComments is String) {
            try {
              final decoded = jsonDecode(rawComments);
              if (decoded is List) {
                parsedComments = decoded
                    .map((c) => CommentData.fromJson(c as Map<String, dynamic>))
                    .toList();
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
          date: data['date'] != null
              ? DateTime.parse(data['date'] as String).toLocal()
              : DateTime.now(),
          isImageCard: data['is_image_card'] ?? false,
          position: data['position'] ?? 0,
          mood: data['mood'] ?? '😍',
          photoUrls: List<String>.from(data['photo_urls'] ?? []),
          isPinned: data['is_pinned'] ?? false,
          comments: parsedComments,
        );
      }).toList();

      parsed.sort(
        (a, b) =>
            _isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
      );

      for (var i = 0; i < parsed.length; i++) {
        parsed[i] = parsed[i].copyWith(position: i);
      }

      _timelineItems = parsed;
      await _repository.saveTimelineItems(_timelineItems);
      if (!isDisposed) notifyListeners();
    } catch (e) {
      debugPrint('TimelineProvider.syncInitialData error: $e');
    }
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    // Filter out locally deleted items to handle stream filter/delete timing issues
    final activeDataList = dataList.where((data) {
      final id = data['id'] as String;
      return !_locallyDeletedIds.contains(id);
    }).toList();

    final incoming = activeDataList.map((data) {
      final rawComments = data['comments'];
      List<CommentData> parsedComments = [];
      if (rawComments != null) {
        if (rawComments is List) {
          parsedComments = rawComments
              .map((c) => CommentData.fromJson(c as Map<String, dynamic>))
              .toList();
        } else if (rawComments is String) {
          try {
            final decoded = jsonDecode(rawComments);
            if (decoded is List) {
              parsedComments = decoded
                  .map((c) => CommentData.fromJson(c as Map<String, dynamic>))
                  .toList();
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
        date: data['date'] != null
            ? DateTime.parse(data['date'] as String).toLocal()
            : DateTime.now(),
        isImageCard: data['is_image_card'] ?? false,
        position: data['position'] ?? 0,
        mood: data['mood'] ?? '😍',
        photoUrls: List<String>.from(data['photo_urls'] ?? []),
        isPinned: data['is_pinned'] ?? false,
        comments: parsedComments,
      );
    }).toList();

    incoming.sort(
      (a, b) =>
          _isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
    );

    if (!_isLoading) {
      // Detect additions by partner
      final added = incoming
          .where((inc) => !_timelineItems.any((old) => old.id == inc.id))
          .toList();
      for (var item in added) {
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

      // Detect edits/updates by partner
      for (var inc in incoming) {
        final matchIndex = _timelineItems.indexWhere((old) => old.id == inc.id);
        if (matchIndex != -1) {
          final match = _timelineItems[matchIndex];
          if (match.title != inc.title ||
              match.description != inc.description ||
              match.date != inc.date ||
              match.networkImageUrl != inc.networkImageUrl) {
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
      }

      // Detect deletions by partner
      final deleted = _timelineItems
          .where(
            (old) =>
                !incoming.any((inc) => inc.id == old.id) &&
                !_locallyDeletedIds.contains(old.id),
          )
          .toList();
      for (var item in deleted) {
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

    _timelineItems = incoming;
    for (var i = 0; i < _timelineItems.length; i++) {
      _timelineItems[i] = _timelineItems[i].copyWith(position: i);
    }
    _clampCurrentScrubIndex();
    _isLoading = false;
    if (!isDisposed) notifyListeners();

    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('TimelineProvider: Supabase sync error: $error');
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    _isLoading = true;
    if (!isDisposed) notifyListeners();

    try {
      _timelineItems = await _repository.loadTimelineItems();
      _timelineItems.sort(
        (a, b) =>
            _isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
      );
      for (var i = 0; i < _timelineItems.length; i++) {
        _timelineItems[i] = _timelineItems[i].copyWith(position: i);
      }
      _clampCurrentScrubIndex();
    } catch (e, st) {
      debugPrint('TimelineProvider._loadTimeline failed: $e\n$st');
      _timelineItems = [];
    } finally {
      _isLoading = false;
      if (!isDisposed) notifyListeners();
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
                .upload(
                  storagePath,
                  file,
                  fileOptions: const FileOptions(upsert: true),
                );
            imageRef = storagePath;
          }
        }

        // Calculate chronological position of this item
        final sortedList = List<TimelineItemData>.from(_timelineItems)
          ..add(item);
        sortedList.sort(
          (a, b) => _isAscending
              ? a.date.compareTo(b.date)
              : b.date.compareTo(a.date),
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
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('comments') &&
              (errorStr.contains('column') ||
                  errorStr.contains('pgrst204') ||
                  errorStr.contains('does not exist') ||
                  errorStr.contains('not found'))) {
            final fallbackData = Map<String, dynamic>.from(dbData)
              ..remove('comments');
            await Supabase.instance.client
                .from('timeline_items')
                .upsert(fallbackData);
          } else {
            rethrow;
          }
        }

        // Trigger push notification to partner
        try {
          await NotificationService().sendPartnerNotification(
            title: 'New Memory Shared 📸',
            body: 'A new memory was added: ${item.title}',
            feature: 'timeline',
            itemId: item.id,
          );
        } catch (fcmError) {
          debugPrint(
            'TimelineProvider: Failed to trigger push notification: $fcmError',
          );
        }
      } catch (e) {
        debugPrint('TimelineProvider.addTimelineItem Supabase error: $e');
        _timelineItems.add(item);
        _timelineItems.sort(
          (a, b) => _isAscending
              ? a.date.compareTo(b.date)
              : b.date.compareTo(a.date),
        );
        for (var i = 0; i < _timelineItems.length; i++) {
          _timelineItems[i] = _timelineItems[i].copyWith(position: i);
        }
        _clampCurrentScrubIndex();
        await _persist();
      }
    } else {
      _timelineItems.add(item);
      _timelineItems.sort(
        (a, b) =>
            _isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
      );
      for (var i = 0; i < _timelineItems.length; i++) {
        _timelineItems[i] = _timelineItems[i].copyWith(position: i);
      }
      _clampCurrentScrubIndex();
      await _persist();
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Memory added 📸',
      description: 'Added: "${item.title}"',
      icon: '📸',
      referenceId: item.id,
      route: 'timeline',
    );
  }

  Future<void> updateTimelineItem(
    String id,
    TimelineItemData updatedItem,
  ) async {
    _localMutations.add(id);
    final index = _timelineItems.indexWhere((item) => item.id == id);
    if (index == -1) {
      debugPrint('TimelineProvider.updateTimelineItem: id $id not found');
      return;
    }

    if (coupleId != null) {
      try {
        String? imageRef = updatedItem.networkImageUrl;
        if (updatedItem.imagePath != null &&
            updatedItem.imagePath != _timelineItems[index].imagePath) {
          final file = File(updatedItem.imagePath!);
          if (await file.exists()) {
            final storagePath =
                'couples/$coupleId/timeline/${updatedItem.id}.jpg';
            await Supabase.instance.client.storage
                .from(StorageBuckets.timeline)
                .upload(
                  storagePath,
                  file,
                  fileOptions: const FileOptions(upsert: true),
                );
            imageRef = storagePath;
            // The object is overwritten in place (same path, upsert), so any
            // signed URL and cached bytes for it are now stale.
            await StorageUrlService.instance.evict(
              bucket: StorageBuckets.timeline,
              ref: storagePath,
            );
            await CachedNetworkImage.evictFromCache(
              StorageUrlService.cacheKeyFor(
                bucket: StorageBuckets.timeline,
                ref: storagePath,
              ),
            );
          }
        }

        // Calculate chronological position of this item
        final sortedList = List<TimelineItemData>.from(_timelineItems);
        final idx = sortedList.indexWhere((item) => item.id == updatedItem.id);
        if (idx != -1) {
          sortedList[idx] = updatedItem;
        } else {
          sortedList.add(updatedItem);
        }
        sortedList.sort(
          (a, b) => _isAscending
              ? a.date.compareTo(b.date)
              : b.date.compareTo(a.date),
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
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('comments') &&
              (errorStr.contains('column') ||
                  errorStr.contains('pgrst204') ||
                  errorStr.contains('does not exist') ||
                  errorStr.contains('not found'))) {
            final fallbackData = Map<String, dynamic>.from(dbData)
              ..remove('comments');
            await Supabase.instance.client
                .from('timeline_items')
                .upsert(fallbackData);
          } else {
            rethrow;
          }
        }
      } catch (e) {
        debugPrint('TimelineProvider.updateTimelineItem Supabase error: $e');
        _timelineItems[index] = updatedItem;
        _timelineItems.sort(
          (a, b) => _isAscending
              ? a.date.compareTo(b.date)
              : b.date.compareTo(a.date),
        );
        for (var i = 0; i < _timelineItems.length; i++) {
          _timelineItems[i] = _timelineItems[i].copyWith(position: i);
        }
        _clampCurrentScrubIndex();
        await _persist();
      }
    } else {
      _timelineItems[index] = updatedItem;
      _timelineItems.sort(
        (a, b) =>
            _isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
      );
      for (var i = 0; i < _timelineItems.length; i++) {
        _timelineItems[i] = _timelineItems[i].copyWith(position: i);
      }
      _clampCurrentScrubIndex();
      await _persist();
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: 'Memory updated ✏️',
      description: 'Updated: "${updatedItem.title}"',
      icon: '✏️',
      referenceId: id,
      route: 'timeline',
    );
  }

  Future<void> deleteTimelineItem(String id) async {
    _localMutations.add(id);
    final index = _timelineItems.indexWhere((item) => item.id == id);
    if (index == -1) {
      debugPrint('TimelineProvider.deleteTimelineItem: id $id not found');
      return;
    }

    // Add to locally deleted set to prevent stream updates from bringing it back
    _locallyDeletedIds.add(id);

    final item = _timelineItems[index];
    if (item.imagePath != null) {
      try {
        await _repository.deleteImage(item.imagePath!);
      } catch (e, st) {
        debugPrint('Failed to delete image ${item.imagePath}: $e\n$st');
      }
    }

    // Update local state first for immediate UI response
    _timelineItems.removeAt(index);
    for (var i = 0; i < _timelineItems.length; i++) {
      _timelineItems[i] = _timelineItems[i].copyWith(position: i);
    }
    _clampCurrentScrubIndex();
    notifyListeners();
    await _persist();

    if (coupleId != null) {
      try {
        await Supabase.instance.client
            .from('timeline_items')
            .delete()
            .eq('id', id);

        try {
          final storagePath = 'couples/$coupleId/timeline/$id.jpg';
          await Supabase.instance.client.storage.from('timeline').remove([
            storagePath,
          ]);
        } catch (_) {}

        // Update positions of remaining items in the database
        final remaining = List<TimelineItemData>.from(_timelineItems);
        for (var i = 0; i < remaining.length; i++) {
          await Supabase.instance.client
              .from('timeline_items')
              .update({'position': i})
              .eq('id', remaining[i].id);
        }
      } catch (e) {
        debugPrint('TimelineProvider.deleteTimelineItem Supabase error: $e');
      }
    }

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
    if (oldIndex < 0 || oldIndex >= _timelineItems.length) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    newIndex = newIndex.clamp(0, _timelineItems.length - 1);

    final item = _timelineItems.removeAt(oldIndex);
    _timelineItems.insert(newIndex, item);

    if (coupleId != null) {
      try {
        for (var i = 0; i < _timelineItems.length; i++) {
          await Supabase.instance.client
              .from('timeline_items')
              .update({'position': i})
              .eq('id', _timelineItems[i].id);
        }
        _clampCurrentScrubIndex();
      } catch (e) {
        debugPrint('TimelineProvider.reorderTimelineItems Supabase error: $e');
        for (var i = 0; i < _timelineItems.length; i++) {
          _timelineItems[i] = _timelineItems[i].copyWith(position: i);
        }
        _clampCurrentScrubIndex();
        await _persist();
      }
    } else {
      for (var i = 0; i < _timelineItems.length; i++) {
        _timelineItems[i] = _timelineItems[i].copyWith(position: i);
      }
      _clampCurrentScrubIndex();
      await _persist();
    }
  }

  Future<String?> pickImage(BuildContext context) async {
    final hasPermission = await PermissionService().requestPhotosPermission(
      context,
    );
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
        debugPrint('TimelineProvider.pickImage: source file missing');
        return null;
      }
      return await _repository.saveImageToStorage(source);
    } catch (e, st) {
      debugPrint('TimelineProvider.pickImage failed: $e\n$st');
      return null;
    }
  }

  Future<void> _persist() async {
    await _persistLocalOnly();
    if (!isDisposed) notifyListeners();
  }

  Future<void> _persistLocalOnly() async {
    try {
      await _repository.saveTimelineItems(_timelineItems);
    } catch (e, st) {
      debugPrint('TimelineProvider._persistLocalOnly failed: $e\n$st');
    }
  }

  Future<void> addCommentToItem(
    String itemId,
    String content,
    String authorName,
  ) async {
    final index = _timelineItems.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final updatedComments =
        List<CommentData>.from(_timelineItems[index].comments)..add(
          CommentData(
            authorName: authorName,
            content: content,
            date: DateTime.now(),
          ),
        );

    final updatedItem = _timelineItems[index].copyWith(
      comments: updatedComments,
    );
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
        debugPrint('TimelineProvider: Failed to send comment notification: $e');
      }
    }
  }

  Future<void> deleteCommentFromItem(String itemId, String commentId) async {
    final index = _timelineItems.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final updatedComments = _timelineItems[index].comments
        .where((c) => c.id != commentId)
        .toList();

    final updatedItem = _timelineItems[index].copyWith(
      comments: updatedComments,
    );
    await updateTimelineItem(itemId, updatedItem);
  }

  Future<void> togglePinComment(String itemId, String commentId) async {
    final index = _timelineItems.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final updatedComments = _timelineItems[index].comments.map((c) {
      if (c.id == commentId) {
        return c.copyWith(isPinned: !c.isPinned);
      }
      return c;
    }).toList();

    final updatedItem = _timelineItems[index].copyWith(
      comments: updatedComments,
    );
    await updateTimelineItem(itemId, updatedItem);
  }
}
