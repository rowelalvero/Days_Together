import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/services/supabase_sync_service.dart';
import 'package:uuid/uuid.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/services/noteit_sync_manager.dart';
import 'package:days_together/services/recent_activity_service.dart';

class NoteitProvider with ChangeNotifier {
  static const String _storageKey = 'love_notes_items';

  List<NoteitItem> _notes = [];
  bool _isLoading = true;
  bool _disposed = false;

  String? _coupleId;
  String? _userId;
  StreamSubscription? _syncSub;

  List<NoteitItem> get notes => _coupleId == null ? const [] : List.unmodifiable(_notes);
  bool get isLoading => _isLoading;
  String? get coupleId => _coupleId;
  String? get userId => _userId;

  NoteitItem? get latestReceived {
    try {
      return _notes.firstWhere((n) => n.sender == 'partner');
    } catch (_) {
      return null;
    }
  }

  NoteitItem? get latestSent {
    try {
      return _notes.firstWhere((n) => n.sender == 'you');
    } catch (_) {
      return null;
    }
  }

  NoteitProvider() {
    _loadNotes();
  }

  void updateRelationship(RelationshipProvider relationship) {
    final bool credentialsChanged = _coupleId != relationship.coupleId || _userId != relationship.userId;
    final bool shouldSubscribe = _syncSub == null && relationship.coupleId != null && relationship.userId != null && relationship.isFirebaseAvailable;

    if (credentialsChanged || shouldSubscribe) {
      _coupleId = relationship.coupleId;
      _userId = relationship.userId;

      _syncSub?.cancel();
      _syncSub = null;

      if (_coupleId != null && _userId != null) {
        NoteitSyncManager.instance.initialize(this);
        if (relationship.isFirebaseAvailable) {
          _initSupabaseSync();
        } else {
          _loadNotes();
        }
      } else {
        _loadNotes();
      }
    }
  }

  void _initSupabaseSync() {
    if (_coupleId == null || _userId == null) return;
    _isLoading = true;
    if (!_disposed) notifyListeners();

    _syncSub = SupabaseSyncService.instance.subscribeToCoupleData(
      tableName: 'love_notes',
      coupleId: _coupleId!,
      onData: (dataList) {
        // Identify local unsynced love notes to preserve optimistic states
        final localUnsynced = _notes.where((n) => n.syncStatus != SyncStatus.synced && n.sender == 'you').toList();

        final filteredList = dataList.where((data) => data['type'] != 'chat').toList();
        final serverNotes = filteredList.map((data) {
          final typeStr = data['type'] as String? ?? 'text';
          final type = NoteitType.values.firstWhere(
            (t) => t.name == typeStr,
            orElse: () => NoteitType.text,
          );
          final senderId = data['sender_id'] as String? ?? '';
          final sender = (senderId == _userId) ? 'you' : 'partner';

          return NoteitItem(
            id: data['id'] as String,
            type: type,
            content: data['content'] as String?,
            imageUrl: data['image_url'] as String?,
            sender: sender,
            createdAt: data['created_at'] != null
                ? DateTime.parse(data['created_at'] as String)
                : DateTime.now(),
            backgroundColor: data['background_color'] != null
                ? Color(data['background_color'] as int)
                : null,
            syncStatus: SyncStatus.synced,
          );
        }).toList();

        // Merge local optimistic unsynced notes with incoming server notes
        final Map<String, NoteitItem> mergedMap = {};
        for (var note in serverNotes) {
          mergedMap[note.id] = note;
        }
        for (var note in localUnsynced) {
          if (!mergedMap.containsKey(note.id)) {
            mergedMap[note.id] = note;
          }
        }

        if (!_isLoading) {
          // Detect additions by partner
          final added = serverNotes.where((srv) => srv.sender == 'partner' && !_notes.any((old) => old.id == srv.id)).toList();
          for (var note in added) {
            String title = 'Partner sent a love note 💌';
            String desc = 'Shared a new text love note';
            String icon = '✍️';
            String route = 'love_notes';

            if (note.type == NoteitType.drawing) {
              title = 'Partner created a doodle 🎨';
              desc = 'Drew and shared a new doodle';
              icon = '🎨';
              route = 'doodle_notes';
            } else if (note.type == NoteitType.photo) {
              title = 'Partner shared photo note 📸';
              desc = 'Shared a new photo note';
              icon = '📷';
              route = 'love_notes';
            }

            RecentActivityService.instance.logActivity(
              activityType: 'created',
              title: title,
              description: desc,
              icon: icon,
              referenceId: note.id,
              route: route,
            );
          }

          // Detect deletions by partner
          final deleted = _notes.where((old) => old.sender == 'partner' && !serverNotes.any((srv) => srv.id == old.id)).toList();
          for (var note in deleted) {
            RecentActivityService.instance.logActivity(
              activityType: 'deleted',
              title: note.type == NoteitType.drawing ? "Partner's doodle deleted 🗑️" : "Partner's love note deleted 🗑️",
              description: note.type == NoteitType.drawing ? 'Partner deleted a doodle' : 'Partner deleted a love note',
              icon: '🗑️',
              referenceId: note.id,
              route: note.type == NoteitType.drawing ? 'doodle_notes' : 'love_notes',
            );
          }
        }

        _notes = mergedMap.values.toList();
        _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
        if (!_disposed) notifyListeners();

        _persistLocalOnly();
      },
      onError: (err) {
        debugPrint('NoteitProvider: Supabase sync error: $err');
        _loadNotes();
      },
    );
  }

  Future<void> _loadNotes() async {
    _isLoading = true;
    if (!_disposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _notes = jsonList.map((j) => NoteitItem.fromJson(j)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _prepopulateTutorial();
      }
    } catch (e, st) {
      debugPrint('NoteitProvider._loadNotes failed: $e\n$st');
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _prepopulateTutorial() {
    _notes = [
      NoteitItem(
        type: NoteitType.text,
        content:
            'Hi there! Welcome to Doodle Notes! 💌 Draw a doodle, choose a picture, or write a note to send it directly to your partner!',
        sender: 'partner',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        backgroundColor: const Color(0xFF9D4EDD),
        syncStatus: SyncStatus.synced,
      ),
      NoteitItem(
        type: NoteitType.drawing,
        content: _generateHeartStrokes(),
        sender: 'partner',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        backgroundColor: const Color(0xFFFF4D6D),
        syncStatus: SyncStatus.synced,
      ),
    ];
    _persist();
  }

  void updateItemSyncStatus(String id, SyncStatus status) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notes[idx] = _notes[idx].copyWith(syncStatus: status);
      if (!_disposed) notifyListeners();
      _persistLocalOnly();
    }
  }

  Future<void> sendDrawing(String strokes, Color bgColor) async {
    final newItem = NoteitItem(
      type: NoteitType.drawing,
      content: strokes,
      sender: 'you',
      backgroundColor: bgColor,
      syncStatus: SyncStatus.sending,
    );

    _notes.insert(0, newItem);
    await _persist();

    if (_coupleId != null && _userId != null) {
      await NoteitSyncManager.instance.enqueue(
        NoteitSyncTask(
          id: newItem.id,
          type: NoteitType.drawing,
          content: strokes,
          backgroundColor: bgColor,
          createdAt: newItem.createdAt,
        ),
      );
    } else {
      updateItemSyncStatus(newItem.id, SyncStatus.failed);
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Created doodle 🎨',
      description: 'Drew and shared a new doodle',
      icon: '🎨',
      referenceId: newItem.id,
      route: 'doodle_notes',
    );
  }

  Future<void> sendText(String text, Color bgColor) async {
    final newItem = NoteitItem(
      type: NoteitType.text,
      content: text,
      sender: 'you',
      backgroundColor: bgColor,
      syncStatus: SyncStatus.sending,
    );

    _notes.insert(0, newItem);
    await _persist();

    if (_coupleId != null && _userId != null) {
      await NoteitSyncManager.instance.enqueue(
        NoteitSyncTask(
          id: newItem.id,
          type: NoteitType.text,
          content: text,
          backgroundColor: bgColor,
          createdAt: newItem.createdAt,
        ),
      );
    } else {
      updateItemSyncStatus(newItem.id, SyncStatus.failed);
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Sent love note 💌',
      description: 'Shared a new text love note',
      icon: '✍️',
      referenceId: newItem.id,
      route: 'love_notes',
    );
  }

  Future<void> sendPhoto(String originalPath) async {
    final noteId = const Uuid().v4();
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'noteit_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newPath = '${directory.path}/$fileName';
      await File(originalPath).copy(newPath);

      final newItem = NoteitItem(
        id: noteId,
        type: NoteitType.photo,
        imagePath: newPath,
        sender: 'you',
        syncStatus: SyncStatus.sending,
      );

      _notes.insert(0, newItem);
      await _persist();

      if (_coupleId != null && _userId != null) {
        await NoteitSyncManager.instance.enqueue(
          NoteitSyncTask(
            id: noteId,
            type: NoteitType.photo,
            imagePath: newPath,
            createdAt: newItem.createdAt,
          ),
        );
      } else {
        updateItemSyncStatus(noteId, SyncStatus.failed);
      }

      await RecentActivityService.instance.logActivity(
        activityType: 'created',
        title: 'Sent photo note 📸',
        description: 'Shared a new photo note',
        icon: '📷',
        referenceId: newItem.id,
        route: 'love_notes',
      );
    } catch (e) {
      debugPrint('NoteitProvider.sendPhoto failed: $e');
    }
  }

  Future<void> sendCanvas(String jsonContent, String? localImagePath) async {
    final noteId = const Uuid().v4();
    String? finalLocalPath;
    
    if (localImagePath != null) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'noteit_canvas_${DateTime.now().millisecondsSinceEpoch}.jpg';
        finalLocalPath = '${directory.path}/$fileName';
        await File(localImagePath).copy(finalLocalPath);
      } catch (e) {
        debugPrint('NoteitProvider: Failed to copy canvas background: $e');
      }
    }

    final newItem = NoteitItem(
      id: noteId,
      type: NoteitType.drawing, // Use drawing as unified type
      content: jsonContent,
      imagePath: finalLocalPath,
      sender: 'you',
      syncStatus: SyncStatus.sending,
    );

    _notes.insert(0, newItem);
    await _persist();

    if (_coupleId != null && _userId != null) {
      await NoteitSyncManager.instance.enqueue(
        NoteitSyncTask(
          id: noteId,
          type: NoteitType.drawing,
          content: jsonContent,
          imagePath: finalLocalPath,
          createdAt: newItem.createdAt,
        ),
      );
    } else {
      updateItemSyncStatus(noteId, SyncStatus.failed);
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Created canvas note 🎨',
      description: 'Shared an interactive canvas note',
      icon: '🎨',
      referenceId: noteId,
      route: 'doodle_notes',
    );
  }

  Future<void> deleteNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final noteToDelete = _notes[index];
    if (noteToDelete.imagePath != null) {
      try {
        final file = File(noteToDelete.imagePath!);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('NoteitProvider: Failed to delete image file: $e');
      }
    }

    if (_coupleId != null) {
      try {
        await Supabase.instance.client.from('love_notes').delete().eq('id', id);

        if (noteToDelete.type == NoteitType.photo) {
          try {
            final storagePath = 'couples/$_coupleId/love_notes/$id.jpg';
            await Supabase.instance.client.storage.from('love-notes').remove([
              storagePath,
            ]);
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('NoteitProvider.deleteNote Supabase error: $e');
        _notes.removeAt(index);
        await _persist();
      }
    } else {
      _notes.removeAt(index);
      await _persist();
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'deleted',
      title: noteToDelete.type == NoteitType.drawing ? 'Doodle deleted 🗑️' : 'Love note deleted 🗑️',
      description: noteToDelete.type == NoteitType.drawing ? 'Deleted a doodle' : 'Deleted a love note',
      icon: '🗑️',
      referenceId: id,
      route: noteToDelete.type == NoteitType.drawing ? 'doodle_notes' : 'love_notes',
    );
  }

  String _generateHeartStrokes() {
    final List<List<Offset>> strokes = [];
    final List<Offset> stroke = [];
    for (double t = 0; t <= 2 * pi; t += 0.08) {
      double x = 150 + 70 * pow(sin(t), 3).toDouble();
      double y =
          150 -
          (55 * cos(t) - 22 * cos(2 * t) - 9 * cos(3 * t) - 4 * cos(4 * t));
      stroke.add(Offset(x, y));
    }
    strokes.add(stroke);
    return _serializeStrokes(strokes);
  }

  String _serializeStrokes(List<List<Offset>> strokes) {
    return strokes
        .map(
          (stroke) => stroke
              .map(
                (p) => '${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}',
              )
              .join(';'),
        )
        .join('|');
  }

  Future<void> _persist() async {
    await _persistLocalOnly();
    if (!_disposed) notifyListeners();
  }

  Future<void> _persistLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _notes.map((n) => n.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('NoteitProvider._persistLocalOnly failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _disposed = true;
    super.dispose();
  }
}
