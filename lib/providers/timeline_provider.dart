import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/repositories/timeline_repository.dart';
import 'package:days_together/providers/relationship_provider.dart';

class TimelineProvider with ChangeNotifier {
  final TimelineRepository _repository = TimelineRepository();
  final ImagePicker _picker = ImagePicker();
  List<TimelineItemData> _timelineItems = [];
  bool _isLoading = true;
  bool _disposed = false;

  String? _coupleId;
  String? _userId;
  StreamSubscription? _syncSub;

  List<TimelineItemData> get timelineItems => List.unmodifiable(_timelineItems);
  bool get isLoading => _isLoading;

  TimelineProvider() {
    _loadTimeline();
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
        _loadTimeline();
      }
    }
  }

  void _initSupabaseSync() {
    if (_coupleId == null) return;
    _isLoading = true;
    if (!_disposed) notifyListeners();

    _syncSub = Supabase.instance.client
        .from('timeline_items')
        .stream(primaryKey: ['id'])
        .eq('couple_id', _coupleId!)
        .listen((dataList) {
      _timelineItems = dataList.map((data) {
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
          date: data['date'] != null ? DateTime.parse(data['date'] as String) : DateTime.now(),
          isImageCard: data['is_image_card'] ?? false,
          position: data['position'] ?? 0,
          mood: data['mood'] ?? '😍',
          photoUrls: List<String>.from(data['photo_urls'] ?? []),
          isPinned: data['is_pinned'] ?? false,
          comments: parsedComments,
        );
      }).toList();

      _timelineItems.sort((a, b) => a.position.compareTo(b.position));
      _isLoading = false;
      if (!_disposed) notifyListeners();

      _persistLocalOnly();
    }, onError: (err) {
      debugPrint('TimelineProvider: Supabase sync error: $err');
      _loadTimeline();
    });
  }

  Future<void> _loadTimeline() async {
    _isLoading = true;
    if (!_disposed) notifyListeners();

    try {
      _timelineItems = await _repository.loadTimelineItems();
    } catch (e, st) {
      debugPrint('TimelineProvider._loadTimeline failed: $e\n$st');
      _timelineItems = [];
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> addTimelineItem(TimelineItemData item) async {
    if (_coupleId != null) {
      try {
        String? downloadUrl;
        if (item.imagePath != null) {
          final file = File(item.imagePath!);
          if (await file.exists()) {
            final storagePath = 'couples/$_coupleId/timeline/${item.id}.jpg';
            await Supabase.instance.client.storage
                .from('timeline')
                .upload(
                  storagePath,
                  file,
                  fileOptions: const FileOptions(upsert: true),
                );
            downloadUrl = Supabase.instance.client.storage
                .from('timeline')
                .getPublicUrl(storagePath);
          }
        }

        final Map<String, dynamic> dbData = {
          'id': item.id,
          'couple_id': _coupleId,
          'title': item.title,
          'description': item.description,
          'location': item.location,
          'image_path': item.imagePath,
          'network_image_url': downloadUrl ?? item.networkImageUrl,
          'date': item.date.toIso8601String(),
          'is_image_card': item.isImageCard,
          'position': item.position,
          'mood': item.mood,
          'photo_urls': item.photoUrls,
          'is_pinned': item.isPinned,
          'comments': item.comments.map((c) => c.toJson()).toList(),
        };

        try {
          await Supabase.instance.client
              .from('timeline_items')
              .upsert(dbData);
        } catch (e) {
          if (e.toString().contains('column') && e.toString().contains('does not exist')) {
            final fallbackData = Map<String, dynamic>.from(dbData)..remove('comments');
            await Supabase.instance.client
                .from('timeline_items')
                .upsert(fallbackData);
          } else {
            rethrow;
          }
        }
      } catch (e) {
        debugPrint('TimelineProvider.addTimelineItem Supabase error: $e');
        _timelineItems.add(item);
        await _persist();
      }
    } else {
      _timelineItems.add(item);
      await _persist();
    }
  }

  Future<void> updateTimelineItem(
      String id, TimelineItemData updatedItem) async {
    final index = _timelineItems.indexWhere((item) => item.id == id);
    if (index == -1) {
      debugPrint('TimelineProvider.updateTimelineItem: id $id not found');
      return;
    }

    if (_coupleId != null) {
      try {
        String? downloadUrl = updatedItem.networkImageUrl;
        if (updatedItem.imagePath != null && updatedItem.imagePath != _timelineItems[index].imagePath) {
          final file = File(updatedItem.imagePath!);
          if (await file.exists()) {
            final storagePath = 'couples/$_coupleId/timeline/${updatedItem.id}.jpg';
            await Supabase.instance.client.storage
                .from('timeline')
                .upload(
                  storagePath,
                  file,
                  fileOptions: const FileOptions(upsert: true),
                );
            downloadUrl = Supabase.instance.client.storage
                .from('timeline')
                .getPublicUrl(storagePath);
          }
        }

        final Map<String, dynamic> dbData = {
          'id': updatedItem.id,
          'couple_id': _coupleId,
          'title': updatedItem.title,
          'description': updatedItem.description,
          'location': updatedItem.location,
          'image_path': updatedItem.imagePath,
          'network_image_url': downloadUrl,
          'date': updatedItem.date.toIso8601String(),
          'is_image_card': updatedItem.isImageCard,
          'position': updatedItem.position,
          'mood': updatedItem.mood,
          'photo_urls': updatedItem.photoUrls,
          'is_pinned': updatedItem.isPinned,
          'comments': updatedItem.comments.map((c) => c.toJson()).toList(),
        };

        try {
          await Supabase.instance.client
              .from('timeline_items')
              .upsert(dbData);
        } catch (e) {
          if (e.toString().contains('column') && e.toString().contains('does not exist')) {
            final fallbackData = Map<String, dynamic>.from(dbData)..remove('comments');
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
        await _persist();
      }
    } else {
      _timelineItems[index] = updatedItem;
      await _persist();
    }
  }

  Future<void> deleteTimelineItem(String id) async {
    final index = _timelineItems.indexWhere((item) => item.id == id);
    if (index == -1) {
      debugPrint('TimelineProvider.deleteTimelineItem: id $id not found');
      return;
    }
    final item = _timelineItems[index];
    if (item.imagePath != null) {
      try {
        await _repository.deleteImage(item.imagePath!);
      } catch (e, st) {
        debugPrint('Failed to delete image ${item.imagePath}: $e\n$st');
      }
    }

    if (_coupleId != null) {
      try {
        await Supabase.instance.client
            .from('timeline_items')
            .delete()
            .eq('id', id);

        try {
          final storagePath = 'couples/$_coupleId/timeline/$id.jpg';
          await Supabase.instance.client.storage
              .from('timeline')
              .remove([storagePath]);
        } catch (_) {}

        final remaining = _timelineItems.where((i) => i.id != id).toList();
        for (var i = 0; i < remaining.length; i++) {
          await Supabase.instance.client
              .from('timeline_items')
              .update({'position': i})
              .eq('id', remaining[i].id);
        }
      } catch (e) {
        debugPrint('TimelineProvider.deleteTimelineItem Supabase error: $e');
        _timelineItems.removeAt(index);
        for (var i = 0; i < _timelineItems.length; i++) {
          _timelineItems[i].position = i;
        }
        await _persist();
      }
    } else {
      _timelineItems.removeAt(index);
      for (var i = 0; i < _timelineItems.length; i++) {
        _timelineItems[i].position = i;
      }
      await _persist();
    }
  }

  Future<void> reorderTimelineItems(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _timelineItems.length) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    newIndex = newIndex.clamp(0, _timelineItems.length - 1);

    final item = _timelineItems.removeAt(oldIndex);
    _timelineItems.insert(newIndex, item);

    if (_coupleId != null) {
      try {
        for (var i = 0; i < _timelineItems.length; i++) {
          await Supabase.instance.client
              .from('timeline_items')
              .update({'position': i})
              .eq('id', _timelineItems[i].id);
        }
      } catch (e) {
        debugPrint('TimelineProvider.reorderTimelineItems Supabase error: $e');
        for (var i = 0; i < _timelineItems.length; i++) {
          _timelineItems[i].position = i;
        }
        await _persist();
      }
    } else {
      for (var i = 0; i < _timelineItems.length; i++) {
        _timelineItems[i].position = i;
      }
      await _persist();
    }
  }

  Future<String?> pickImage() async {
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
    if (!_disposed) notifyListeners();
  }

  Future<void> _persistLocalOnly() async {
    try {
      await _repository.saveTimelineItems(_timelineItems);
    } catch (e, st) {
      debugPrint('TimelineProvider._persistLocalOnly failed: $e\n$st');
    }
  }

  Future<void> addCommentToItem(String itemId, String content, String authorName) async {
    final index = _timelineItems.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final updatedComments = List<CommentData>.from(_timelineItems[index].comments)
      ..add(CommentData(
        authorName: authorName,
        content: content,
        date: DateTime.now(),
      ));

    final updatedItem = _timelineItems[index].copyWith(comments: updatedComments);
    await updateTimelineItem(itemId, updatedItem);
  }

  Future<void> deleteCommentFromItem(String itemId, String commentId) async {
    final index = _timelineItems.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final updatedComments = _timelineItems[index].comments
        .where((c) => c.id != commentId)
        .toList();

    final updatedItem = _timelineItems[index].copyWith(comments: updatedComments);
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

    final updatedItem = _timelineItems[index].copyWith(comments: updatedComments);
    await updateTimelineItem(itemId, updatedItem);
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _disposed = true;
    super.dispose();
  }
}
