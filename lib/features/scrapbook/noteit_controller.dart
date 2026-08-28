import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' show Color, Offset;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/features/scrapbook/noteit_state.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/services/noteit_sync_manager.dart';
import 'package:days_together/services/recent_activity_service.dart';

/// Riverpod port of `NoteitProvider` (Phase 6a of the architecture
/// migration, ported together with `LoveChatController` since both share
/// the `love_notes` table and its realtime subscription -- see both
/// controllers' shared doc note on the "collision" below).
///
/// **`NoteitSyncManager` ownership is deliberately NOT transferred to this
/// controller yet.** `NoteitSyncManager` is a singleton holding a single
/// `NoteitProvider? _provider` reference (`noteit_sync_manager.dart:70`),
/// set via `initialize(provider)` -- currently called only from
/// `NoteitProvider.updateSession` (`noteit_provider.dart:51-56`). Since
/// Phase 6a doesn't convert any UI, the old `NoteitProvider` is still what
/// `noteit_screen.dart` reads and writes through, and it's still alive in
/// `main.dart`'s `MultiProvider` tree, reacting to the same `CoupleSession`
/// changes this controller's own bridge reacts to. If this controller also
/// called `NoteitSyncManager.instance.initialize(this)` from its
/// `updateSession`, both it and the old provider would race to claim the
/// singleton's one `_provider` slot on every pairing event -- and since
/// nothing reads this controller's state yet, "winning" that race would
/// only ever cost the *old* provider (the one actually in use) its sync
/// status updates, a real regression to the live UI for zero benefit today.
/// So [sendDrawing]/[sendText]/[sendPhoto]/[sendCanvas] still call
/// `NoteitSyncManager.instance.enqueue(...)` (the actual Supabase
/// upload/upsert still happens correctly regardless of which provider
/// "owns" the manager), but this controller's own `updateItemSyncStatus`
/// won't be reached by the queue's status callbacks until Phase 6b retires
/// `NoteitProvider` and this controller becomes the sole `initialize()`
/// caller. Until then, an item created directly through this controller
/// (nothing does today) would visibly stay "sending" forever in its own
/// state, even though the underlying data synced fine.
class NoteitController extends Notifier<NoteitState> with SupabaseLifecycleNotifier<NoteitState> {
  static const String _storageKey = 'love_notes_items';

  @override
  String get tableName => 'love_notes';

  @override
  NoteitState build() {
    // Per ADR-005: chat and scrapbook are exempted from autoDispose's
    // default teardown, since losing and re-establishing the realtime
    // subscription during a brief background/tab-switch would visibly drop
    // incoming messages during the gap.
    ref.keepAlive();
    initSessionLifecycle();
    _loadFromCache();
    return NoteitState(coupleId: coupleId);
  }

  @override
  Future<void> updateSession(CoupleSession session) async {
    await super.updateSession(session);
    if (!ref.mounted) return;
    if (state.coupleId != coupleId) {
      state = state.copyWith(coupleId: coupleId);
    }
    if (session.coupleId != null && session.userId != null) {
      NoteitSyncManager.instance.initialize(this);
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      List<NoteitItem> notes;
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        notes = jsonList.map((j) => NoteitItem.fromJson(j)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        notes = _tutorialNotes();
        if (!ref.mounted) return;
        state = state.copyWith(notes: notes, isLoading: false);
        await _persistLocalOnly();
        return;
      }
      if (!ref.mounted) return;
      state = state.copyWith(notes: notes, isLoading: false);
    } catch (e, st) {
      debugPrint('NoteitController._loadFromCache failed: $e\n$st');
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  List<NoteitItem> _tutorialNotes() {
    return [
      NoteitItem(
        type: NoteitType.text,
        content:
            'Hi there! Welcome to Scrapbook! 💌 Draw a doodle, choose a picture, or write a note to send it directly to your partner!',
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
  }

  @override
  Future<void> purgeCache() async {
    state = state.copyWith(notes: [], isLoading: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('NoteitController.purgeCache error: $e');
    }
  }

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    try {
      final List<dynamic> res =
          await Supabase.instance.client.from('love_notes').select().eq('couple_id', coupleId!);
      if (!ref.mounted) return;
      final filteredList = res.where((data) => data['type'] != 'chat').toList();
      final parsed = filteredList.map((data) => NoteitItem.fromSupabase(data, sessionUserId!)).toList();

      final localUnsynced =
          state.notes.where((n) => n.syncStatus != SyncStatus.synced && n.sender == 'you').toList();
      final Map<String, NoteitItem> mergedMap = {};
      for (final note in parsed) {
        mergedMap[note.id] = note;
      }
      for (final note in localUnsynced) {
        mergedMap.putIfAbsent(note.id, () => note);
      }

      final merged = mergedMap.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(notes: merged, isLoading: false);
      await _persistLocalOnly();
    } catch (e) {
      debugPrint('NoteitController.syncInitialData error: $e');
    }
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    if (!ref.mounted) return;
    final localUnsynced =
        state.notes.where((n) => n.syncStatus != SyncStatus.synced && n.sender == 'you').toList();

    final filteredList = dataList.where((data) => data['type'] != 'chat').toList();
    final serverNotes = filteredList.map((data) => NoteitItem.fromSupabase(data, sessionUserId!)).toList();

    final Map<String, NoteitItem> mergedMap = {};
    for (final note in serverNotes) {
      mergedMap[note.id] = note;
    }
    for (final note in localUnsynced) {
      mergedMap.putIfAbsent(note.id, () => note);
    }

    final wasLoading = state.isLoading;
    final oldNotes = state.notes;

    if (!wasLoading) {
      final added =
          serverNotes.where((srv) => srv.sender == 'partner' && !oldNotes.any((old) => old.id == srv.id)).toList();
      for (final note in added) {
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

      final deleted =
          oldNotes.where((old) => old.sender == 'partner' && !serverNotes.any((srv) => srv.id == old.id)).toList();
      for (final note in deleted) {
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

    final merged = mergedMap.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(notes: merged, isLoading: false);
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('NoteitController: Supabase sync error: $error');
    _loadFromCache();
  }

  void updateItemSyncStatus(String id, SyncStatus status) {
    final idx = state.notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final notes = [...state.notes];
    notes[idx] = notes[idx].copyWith(syncStatus: status);
    state = state.copyWith(notes: notes);
    _persistLocalOnly();
  }

  Future<void> sendDrawing(String strokes, Color bgColor) async {
    final newItem =
        NoteitItem(type: NoteitType.drawing, content: strokes, sender: 'you', backgroundColor: bgColor, syncStatus: SyncStatus.sending);

    state = state.copyWith(notes: [newItem, ...state.notes]);
    await _persist();

    if (coupleId != null && sessionUserId != null) {
      await NoteitSyncManager.instance.enqueue(
        NoteitSyncTask(id: newItem.id, type: NoteitType.drawing, content: strokes, backgroundColor: bgColor, createdAt: newItem.createdAt),
      );
    } else {
      updateItemSyncStatus(newItem.id, SyncStatus.failed);
    }

    if (!ref.mounted) return;
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
    final newItem =
        NoteitItem(type: NoteitType.text, content: text, sender: 'you', backgroundColor: bgColor, syncStatus: SyncStatus.sending);

    state = state.copyWith(notes: [newItem, ...state.notes]);
    await _persist();

    if (coupleId != null && sessionUserId != null) {
      await NoteitSyncManager.instance.enqueue(
        NoteitSyncTask(id: newItem.id, type: NoteitType.text, content: text, backgroundColor: bgColor, createdAt: newItem.createdAt),
      );
    } else {
      updateItemSyncStatus(newItem.id, SyncStatus.failed);
    }

    if (!ref.mounted) return;
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
      if (!ref.mounted) return;

      final newItem = NoteitItem(id: noteId, type: NoteitType.photo, imagePath: newPath, sender: 'you', syncStatus: SyncStatus.sending);

      state = state.copyWith(notes: [newItem, ...state.notes]);
      await _persist();

      if (coupleId != null && sessionUserId != null) {
        await NoteitSyncManager.instance.enqueue(
          NoteitSyncTask(id: noteId, type: NoteitType.photo, imagePath: newPath, createdAt: newItem.createdAt),
        );
      } else {
        updateItemSyncStatus(noteId, SyncStatus.failed);
      }

      if (!ref.mounted) return;
      await RecentActivityService.instance.logActivity(
        activityType: 'created',
        title: 'Sent photo note 📸',
        description: 'Shared a new photo note',
        icon: '📷',
        referenceId: newItem.id,
        route: 'love_notes',
      );
    } catch (e) {
      debugPrint('NoteitController.sendPhoto failed: $e');
    }
  }

  Future<NoteitItem> sendCanvas(String jsonContent, String? localImagePath) async {
    final noteId = const Uuid().v4();
    String? finalLocalPath;

    if (localImagePath != null) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'noteit_canvas_${DateTime.now().millisecondsSinceEpoch}.jpg';
        finalLocalPath = '${directory.path}/$fileName';
        await File(localImagePath).copy(finalLocalPath);
      } catch (e) {
        debugPrint('NoteitController: Failed to copy scrapbook background: $e');
      }
    }

    final newItem = NoteitItem(
      id: noteId,
      type: NoteitType.drawing,
      content: jsonContent,
      imagePath: finalLocalPath,
      sender: 'you',
      syncStatus: SyncStatus.sending,
    );

    if (!ref.mounted) return newItem;
    state = state.copyWith(notes: [newItem, ...state.notes]);
    await _persist();

    if (coupleId != null && sessionUserId != null) {
      await NoteitSyncManager.instance.enqueue(
        NoteitSyncTask(id: noteId, type: NoteitType.drawing, content: jsonContent, imagePath: finalLocalPath, createdAt: newItem.createdAt),
      );
    } else {
      updateItemSyncStatus(noteId, SyncStatus.failed);
    }

    if (ref.mounted) {
      await RecentActivityService.instance.logActivity(
        activityType: 'created',
        title: 'Created scrapbook canvas note 🎨',
        description: 'Shared an interactive scrapbook canvas note',
        icon: '🎨',
        referenceId: noteId,
        route: 'doodle_notes',
      );
    }

    return newItem;
  }

  Future<void> deleteNote(String id) async {
    final index = state.notes.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final noteToDelete = state.notes[index];
    if (noteToDelete.imagePath != null) {
      try {
        final file = File(noteToDelete.imagePath!);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('NoteitController: Failed to delete image file: $e');
      }
    }

    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('love_notes').delete().eq('id', id);

        if (noteToDelete.type == NoteitType.photo) {
          try {
            final storagePath = 'couples/$coupleId/love_notes/$id.jpg';
            await Supabase.instance.client.storage.from('love-notes').remove([storagePath]);
          } catch (e) {
            debugPrint('NoteitController.deleteNote storage remove error: $e');
          }
        }
      } catch (e) {
        debugPrint('NoteitController.deleteNote Supabase error: $e');
        if (!ref.mounted) return;
        state = state.copyWith(notes: [...state.notes]..removeAt(index));
        await _persist();
      }
    } else {
      state = state.copyWith(notes: [...state.notes]..removeAt(index));
      await _persist();
    }

    if (!ref.mounted) return;
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
      double y = 150 - (55 * cos(t) - 22 * cos(2 * t) - 9 * cos(3 * t) - 4 * cos(4 * t));
      stroke.add(Offset(x, y));
    }
    strokes.add(stroke);
    return _serializeStrokes(strokes);
  }

  String _serializeStrokes(List<List<Offset>> strokes) {
    return strokes
        .map((stroke) => stroke.map((p) => '${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}').join(';'))
        .join('|');
  }

  Future<void> _persist() => _persistLocalOnly();

  Future<void> _persistLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.notes.map((n) => n.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('NoteitController._persistLocalOnly failed: $e\n$st');
    }
  }
}

final noteitControllerProvider = NotifierProvider.autoDispose<NoteitController, NoteitState>(
  NoteitController.new,
  dependencies: [coupleSessionProvider],
);
