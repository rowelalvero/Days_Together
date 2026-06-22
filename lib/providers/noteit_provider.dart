import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/providers/relationship_provider.dart';

class NoteitProvider with ChangeNotifier {
  static const String _storageKey = 'love_notes_items';

  List<NoteitItem> _notes = [];
  bool _isLoading = true;
  bool _disposed = false;

  String? _coupleId;
  String? _userId;
  StreamSubscription? _syncSub;

  List<NoteitItem> get notes => List.unmodifiable(_notes);
  bool get isLoading => _isLoading;

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
    if (_coupleId != relationship.coupleId || _userId != relationship.userId) {
      _coupleId = relationship.coupleId;
      _userId = relationship.userId;

      _syncSub?.cancel();
      _syncSub = null;

      if (_coupleId != null &&
          _userId != null &&
          relationship.isFirebaseAvailable) {
        _initSupabaseSync();
      } else {
        _loadNotes();
      }
    }
  }

  void _initSupabaseSync() {
    if (_coupleId == null || _userId == null) return;
    _isLoading = true;
    if (!_disposed) notifyListeners();

    _syncSub = Supabase.instance.client
        .from('love_notes')
        .stream(primaryKey: ['id'])
        .eq('couple_id', _coupleId!)
        .listen(
          (dataList) {
            final filteredList = dataList.where((data) => data['type'] != 'chat').toList();
            _notes = filteredList.map((data) {
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
              );
            }).toList();

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
            'Hi there! Welcome to Love Notes! 💌 Draw a doodle, choose a picture, or write a note to send it directly to your partner!',
        sender: 'partner',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        backgroundColor: const Color(0xFF9D4EDD),
      ),
      NoteitItem(
        type: NoteitType.drawing,
        content: _generateHeartStrokes(),
        sender: 'partner',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        backgroundColor: const Color(0xFFFF4D6D),
      ),
    ];
    _persist();
  }

  Future<void> sendDrawing(String strokes, Color bgColor) async {
    final newItem = NoteitItem(
      type: NoteitType.drawing,
      content: strokes,
      sender: 'you',
      backgroundColor: bgColor,
    );

    if (_coupleId != null && _userId != null) {
      try {
        await Supabase.instance.client.from('love_notes').upsert({
          'id': newItem.id,
          'couple_id': _coupleId,
          'type': 'drawing',
          'content': strokes,
          'sender_id': _userId,
          'created_at': DateTime.now().toIso8601String(),
          'background_color': bgColor.toARGB32().toSigned(32),
        });
      } catch (e) {
        debugPrint('NoteitProvider.sendDrawing Supabase error: $e');
        _notes.insert(0, newItem);
        await _persist();
      }
    } else {
      _notes.insert(0, newItem);
      await _persist();
    }
  }

  Future<void> sendText(String text, Color bgColor) async {
    final newItem = NoteitItem(
      type: NoteitType.text,
      content: text,
      sender: 'you',
      backgroundColor: bgColor,
    );

    if (_coupleId != null && _userId != null) {
      try {
        await Supabase.instance.client.from('love_notes').upsert({
          'id': newItem.id,
          'couple_id': _coupleId,
          'type': 'text',
          'content': text,
          'sender_id': _userId,
          'created_at': DateTime.now().toIso8601String(),
          'background_color': bgColor.toARGB32().toSigned(32),
        });
      } catch (e) {
        debugPrint('NoteitProvider.sendText Supabase error: $e');
        _notes.insert(0, newItem);
        await _persist();
      }
    } else {
      _notes.insert(0, newItem);
      await _persist();
    }
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
      );

      if (_coupleId != null && _userId != null) {
        try {
          final file = File(originalPath);
          final storagePath = 'couples/$_coupleId/love_notes/$noteId.jpg';
          await Supabase.instance.client.storage
              .from('love-notes')
              .upload(
                storagePath,
                file,
                fileOptions: const FileOptions(upsert: true),
              );
          final imageUrl = Supabase.instance.client.storage
              .from('love-notes')
              .getPublicUrl(storagePath);

          await Supabase.instance.client.from('love_notes').upsert({
            'id': noteId,
            'couple_id': _coupleId,
            'type': 'photo',
            'image_url': imageUrl,
            'sender_id': _userId,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('NoteitProvider.sendPhoto Supabase upload error: $e');
          _notes.insert(0, newItem);
          await _persist();
        }
      } else {
        _notes.insert(0, newItem);
        await _persist();
      }
    } catch (e) {
      debugPrint('NoteitProvider.sendPhoto failed: $e');
    }
  }

  Future<void> deleteNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final item = _notes[index];
    if (item.imagePath != null) {
      try {
        final file = File(item.imagePath!);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('NoteitProvider: Failed to delete image file: $e');
      }
    }

    if (_coupleId != null) {
      try {
        await Supabase.instance.client.from('love_notes').delete().eq('id', id);

        if (item.type == NoteitType.photo) {
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
