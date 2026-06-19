import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:days_together/models/vault_item_model.dart';
import 'package:days_together/providers/relationship_provider.dart';

class VaultProvider with ChangeNotifier {
  static const String _storageKey = 'vault_items';
  static const String _pinKey = 'vault_pin';
  static const String _hasPinKey = 'vault_has_pin';

  final ImagePicker _picker = ImagePicker();
  List<VaultItem> _items = [];
  bool _isUnlocked = false;
  bool _hasPin = false;
  int _wrongAttempts = 0;
  bool _isLoading = true;
  bool _disposed = false;

  String? _coupleId;
  String? _userId;
  StreamSubscription? _syncSub;

  List<VaultItem> get items => _isUnlocked ? List.unmodifiable(_items) : [];
  List<VaultItem> get allItems => List.unmodifiable(_items);
  List<VaultItem> get photos =>
      _items.where((i) => i.type == VaultItemType.photo).toList();
  List<VaultItem> get letters =>
      _items.where((i) => i.type == VaultItemType.letter).toList();
  bool get isUnlocked => _isUnlocked;
  bool get hasPin => _hasPin;
  bool get isDecoyMode => _wrongAttempts >= 3;
  bool get isLoading => _isLoading;

  VaultProvider() {
    _loadState();
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

    _syncSub = Supabase.instance.client
        .from('vault_items')
        .stream(primaryKey: ['id'])
        .eq('couple_id', _coupleId!)
        .listen((dataList) {
      _items = dataList.map((data) {
        final typeIndex = data['type'] as int? ?? 0;
        final type = (typeIndex >= 0 && typeIndex < VaultItemType.values.length)
            ? VaultItemType.values[typeIndex]
            : VaultItemType.photo;

        return VaultItem(
          id: data['id'] as String,
          type: type,
          content: data['content'] as String?,
          imageUrl: data['image_url'] as String?,
          createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'] as String) : DateTime.now(),
        );
      }).toList();

      _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _isLoading = false;
      if (!_disposed) notifyListeners();

      _persistLocalOnly();
    }, onError: (err) {
      debugPrint('VaultProvider: Supabase sync error: $err');
      _loadItems();
    });
  }

  Future<void> _loadState() async {
    _isLoading = true;
    if (!_disposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasPin = prefs.getBool(_hasPinKey) ?? false;
      await _loadItems();
    } catch (e, st) {
      debugPrint('VaultProvider._loadState failed: $e\n$st');
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    await prefs.setBool(_hasPinKey, true);
    _hasPin = true;
    _isUnlocked = true;
    if (!_disposed) notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_pinKey);
    if (storedPin == pin) {
      _isUnlocked = true;
      _wrongAttempts = 0;
      if (!_disposed) notifyListeners();
      return true;
    } else {
      _wrongAttempts++;
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  void lock() {
    _isUnlocked = false;
    _wrongAttempts = 0;
    if (!_disposed) notifyListeners();
  }

  void resetDecoy() {
    _wrongAttempts = 0;
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _items = jsonList.map((j) => VaultItem.fromJson(j)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _items = [];
      }
    } catch (e, st) {
      debugPrint('VaultProvider._loadItems failed: $e\n$st');
    }
  }

  Future<void> addPhoto() async {
    if (!_isUnlocked) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (picked == null) return;
      final directory = await getApplicationDocumentsDirectory();
      final photoId = const Uuid().v4();
      final fileName = 'vault_$photoId.jpg';
      final newPath = '${directory.path}/$fileName';
      await File(picked.path).copy(newPath);

      final newItem = VaultItem(
        id: photoId,
        type: VaultItemType.photo,
        imagePath: newPath,
      );

      if (_coupleId != null) {
        try {
          final file = File(picked.path);
          final storagePath = 'couples/$_coupleId/vault_photos/$photoId.jpg';
          await Supabase.instance.client.storage
              .from('vault-photos')
              .upload(
                storagePath,
                file,
                fileOptions: const FileOptions(upsert: true),
              );
          final imageUrl = Supabase.instance.client.storage
              .from('vault-photos')
              .getPublicUrl(storagePath);

          await Supabase.instance.client
              .from('vault_items')
              .upsert({
            'id': photoId,
            'couple_id': _coupleId,
            'type': VaultItemType.photo.index,
            'image_url': imageUrl,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('VaultProvider.addPhoto Supabase upload error: $e');
          _items.insert(0, newItem);
          await _persist();
        }
      } else {
        _items.insert(0, newItem);
        await _persist();
      }
    } catch (e, st) {
      debugPrint('VaultProvider.addPhoto failed: $e\n$st');
    }
  }

  Future<void> addLetter(String content) async {
    if (!_isUnlocked) return;
    final item = VaultItem(
      type: VaultItemType.letter,
      content: content,
    );

    if (_coupleId != null) {
      try {
        await Supabase.instance.client
            .from('vault_items')
            .upsert({
          'id': item.id,
          'couple_id': _coupleId,
          'type': VaultItemType.letter.index,
          'content': content,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('VaultProvider.addLetter Supabase error: $e');
        _items.insert(0, item);
        await _persist();
      }
    } else {
      _items.insert(0, item);
      await _persist();
    }
  }

  Future<void> deleteItem(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final item = _items[index];

    if (item.imagePath != null) {
      try {
        final file = File(item.imagePath!);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('VaultProvider: Failed to delete file: $e');
      }
    }

    if (_coupleId != null) {
      try {
        await Supabase.instance.client
            .from('vault_items')
            .delete()
            .eq('id', id);

        if (item.type == VaultItemType.photo) {
          try {
            final storagePath = 'couples/$_coupleId/vault_photos/$id.jpg';
            await Supabase.instance.client.storage
                .from('vault-photos')
                .remove([storagePath]);
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('VaultProvider.deleteItem Supabase error: $e');
        _items.removeWhere((i) => i.id == id);
        await _persist();
      }
    } else {
      _items.removeWhere((i) => i.id == id);
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
      final jsonList = _items.map((i) => i.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('VaultProvider._persistLocalOnly failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _disposed = true;
    super.dispose();
  }
}
