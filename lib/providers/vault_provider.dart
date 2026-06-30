import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/services/supabase_sync_service.dart';
import 'package:uuid/uuid.dart';
import 'package:days_together/models/vault_item_model.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:flutter/material.dart';
import 'package:days_together/services/permission_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VaultProvider with ChangeNotifier, WidgetsBindingObserver {
  static const String _storageKey = 'vault_items';
  static const String _pinKey = 'vault_pin';
  static const String _hasPinKey = 'vault_has_pin';
  static const String _wrongAttemptsKey = 'vault_wrong_attempts';
  static const String _decoyActivatedAtKey = 'vault_decoy_activated_at';

  static const _secureStorage = FlutterSecureStorage();

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
  List<VaultItem> get allItems => _isUnlocked ? List.unmodifiable(_items) : const [];
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
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      lock();
    }
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
        _loadItems();
      }
    }
  }

  void _initSupabaseSync() {
    if (_coupleId == null) return;
    _isLoading = true;
    if (!_disposed) notifyListeners();

    _syncSub = SupabaseSyncService.instance.subscribeToCoupleData(
      tableName: 'vault_items',
      coupleId: _coupleId!,
      onData: (dataList) {
            _items = dataList.map((data) {
              final typeIndex = data['type'] as int? ?? 0;
              final type =
                  (typeIndex >= 0 && typeIndex < VaultItemType.values.length)
                  ? VaultItemType.values[typeIndex]
                  : VaultItemType.photo;

              return VaultItem(
                id: data['id'] as String,
                type: type,
                content: data['content'] as String?,
                imageUrl: data['image_url'] as String?,
                createdAt: data['created_at'] != null
                    ? DateTime.parse(data['created_at'] as String)
                    : DateTime.now(),
              );
            }).toList();

            _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _isLoading = false;
            if (!_disposed) notifyListeners();

            _persistLocalOnly();
      },
      onError: (err) {
        debugPrint('VaultProvider: Supabase sync error: $err');
        _loadItems();
      },
    );
  }

  Future<void> _loadState() async {
    _isLoading = true;
    if (!_disposed) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasPin = prefs.getBool(_hasPinKey) ?? false;
      
      // Load wrong attempts and decoy state
      _wrongAttempts = prefs.getInt(_wrongAttemptsKey) ?? 0;
      final decoyTimeStr = prefs.getString(_decoyActivatedAtKey);
      if (decoyTimeStr != null) {
        final decoyTime = DateTime.parse(decoyTimeStr);
        final diff = DateTime.now().difference(decoyTime);
        if (diff.inMinutes >= 10) {
          // Timeout expired, auto reset decoy
          _wrongAttempts = 0;
          await prefs.setInt(_wrongAttemptsKey, 0);
          await prefs.remove(_decoyActivatedAtKey);
        }
      }

      // Automatic PIN migration from SharedPreferences to Secure Storage with fallback
      try {
        final storedSharedPin = prefs.getString(_pinKey);
        if (storedSharedPin != null) {
          try {
            await _secureStorage.write(key: _pinKey, value: storedSharedPin);
            await prefs.remove(_pinKey);
          } catch (e) {
            debugPrint('Secure storage write failed during migration: $e. Falling back.');
            await prefs.setString('vault_pin_fallback', storedSharedPin);
          }
          _hasPin = true;
          await prefs.setBool(_hasPinKey, true);
        } else {
          String? securePin;
          try {
            securePin = await _secureStorage.read(key: _pinKey);
          } catch (e) {
            debugPrint('Secure storage read failed: $e. Using fallback.');
            securePin = prefs.getString('vault_pin_fallback');
          }
          _hasPin = securePin != null && securePin.isNotEmpty;
          await prefs.setBool(_hasPinKey, _hasPin);
        }
      } catch (e) {
        debugPrint('Secure storage migration wrapper error: $e');
      }

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
    try {
      await _secureStorage.write(key: _pinKey, value: pin);
    } catch (e) {
      debugPrint('Secure storage write failed: $e. Using fallback.');
      await prefs.setString('vault_pin_fallback', pin);
    }
    await prefs.setBool(_hasPinKey, true);
    _hasPin = true;
    _isUnlocked = true;
    if (!_disposed) notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    String? securePin;
    try {
      securePin = await _secureStorage.read(key: _pinKey);
    } catch (e) {
      debugPrint('Secure storage read failed: $e. Using fallback.');
      securePin = prefs.getString('vault_pin_fallback');
    }

    if (securePin == pin) {
      _isUnlocked = true;
      _wrongAttempts = 0;
      await prefs.setInt(_wrongAttemptsKey, 0);
      await prefs.remove(_decoyActivatedAtKey);
      if (!_disposed) notifyListeners();
      return true;
    } else {
      _wrongAttempts++;
      await prefs.setInt(_wrongAttemptsKey, _wrongAttempts);
      if (_wrongAttempts >= 3) {
        await prefs.setString(_decoyActivatedAtKey, DateTime.now().toIso8601String());
      }
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  Future<void> lock() async {
    _isUnlocked = false;
    _wrongAttempts = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wrongAttemptsKey, 0);
    await prefs.remove(_decoyActivatedAtKey);
    if (!_disposed) notifyListeners();
  }

  Future<void> resetDecoy() async {
    _wrongAttempts = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wrongAttemptsKey, 0);
    await prefs.remove(_decoyActivatedAtKey);
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

  Future<void> addPhoto(BuildContext context) async {
    if (!_isUnlocked) return;
    final hasPermission = await PermissionService().requestPhotosPermission(
      context,
    );
    if (!hasPermission) return;
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

          await Supabase.instance.client.from('vault_items').upsert({
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
    final item = VaultItem(type: VaultItemType.letter, content: content);

    if (_coupleId != null) {
      try {
        await Supabase.instance.client.from('vault_items').upsert({
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
            await Supabase.instance.client.storage.from('vault-photos').remove([
              storagePath,
            ]);
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
    WidgetsBinding.instance.removeObserver(this);
    _syncSub?.cancel();
    _disposed = true;
    super.dispose();
  }
}
