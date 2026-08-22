import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/models/vault_item_model.dart';
import 'package:flutter/material.dart';
import 'package:days_together/services/permission_service.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:days_together/services/recent_activity_service.dart';

import 'package:days_together/services/relationship_lifecycle_manager.dart';
import 'package:days_together/services/storage_url_service.dart';

class VaultProvider extends SupabaseLifecycleProvider
    with WidgetsBindingObserver {
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

  final Set<String> _localMutations = {};

  List<VaultItem> get items => _isUnlocked ? List.unmodifiable(_items) : [];
  List<VaultItem> get allItems =>
      _isUnlocked ? List.unmodifiable(_items) : const [];
  List<VaultItem> get photos =>
      _items.where((i) => i.type == VaultItemType.photo).toList();
  List<VaultItem> get letters =>
      _items.where((i) => i.type == VaultItemType.letter).toList();
  bool get isUnlocked => _isUnlocked;
  bool get hasPin => _hasPin;
  bool get isDecoyMode => _wrongAttempts >= 3;
  bool get isLoading => _isLoading;

  @override
  String get tableName => 'vault_items';

  VaultProvider() : super() {
    _loadState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      lock();
    }
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
          .from('vault_items')
          .select()
          .eq('couple_id', coupleId!);
      final parsed = res.map((data) {
        final typeIndex = data['type'] as int? ?? 0;
        final type = (typeIndex >= 0 && typeIndex < VaultItemType.values.length)
            ? VaultItemType.values[typeIndex]
            : VaultItemType.photo;

        return VaultItem(
          id: data['id'] as String,
          type: type,
          content: data['content'] as String?,
          imagePath: data['image_path'] as String?,
          // Must match the column addPhoto writes and the realtime handler
          // reads. This previously read 'network_image_url', a column nothing
          // writes, so server-synced vault photos lost their image on every
          // cold start until a realtime event happened to arrive.
          imageUrl: data['image_url'] as String?,
          createdAt: data['created_at'] != null
              ? DateTime.parse(data['created_at'] as String)
              : DateTime.now(),
        );
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _items = parsed;
      await _persistLocalOnly();
      if (!isDisposed) notifyListeners();
    } catch (e) {
      debugPrint('VaultProvider.syncInitialData error: $e');
    }
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    final incoming = dataList.map((data) {
      final typeIndex = data['type'] as int? ?? 0;
      final type = (typeIndex >= 0 && typeIndex < VaultItemType.values.length)
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

    incoming.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!_isLoading) {
      // Detect additions by partner
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
          title: "Partner added vault item 🔒",
          description: 'Added a new secure item to the Vault',
          icon: '🔒',
          referenceId: item.id,
          route: 'vault',
        );
      }

      // Detect deletions by partner
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
          title: "Partner removed vault item 🔒",
          description: 'Removed a secure item from the Vault',
          icon: '🔒',
          referenceId: item.id,
          route: 'vault',
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
    debugPrint('VaultProvider: Supabase sync error: $error');
    _loadItems();
  }

  Future<void> _loadState() async {
    _isLoading = true;
    if (!isDisposed) notifyListeners();
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
            debugPrint(
              'Secure storage write failed during migration: $e. Falling back.',
            );
            await prefs.setString(PrefsKeys.vaultPinFallback, storedSharedPin);
          }
          _hasPin = true;
          await prefs.setBool(_hasPinKey, true);
        } else {
          String? securePin;
          try {
            securePin = await _secureStorage.read(key: _pinKey);
          } catch (e) {
            debugPrint('Secure storage read failed: $e. Using fallback.');
            securePin = prefs.getString(PrefsKeys.vaultPinFallback);
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
      if (!isDisposed) notifyListeners();
    }
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _secureStorage.write(key: _pinKey, value: pin);
    } catch (e) {
      debugPrint('Secure storage write failed: $e. Using fallback.');
      await prefs.setString(PrefsKeys.vaultPinFallback, pin);
    }
    await prefs.setBool(_hasPinKey, true);
    _hasPin = true;
    _isUnlocked = true;
    if (!isDisposed) notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    String? securePin;
    try {
      securePin = await _secureStorage.read(key: _pinKey);
    } catch (e) {
      debugPrint('Secure storage read failed: $e. Using fallback.');
      securePin = prefs.getString(PrefsKeys.vaultPinFallback);
    }

    if (securePin == pin) {
      _isUnlocked = true;
      _wrongAttempts = 0;
      await prefs.setInt(_wrongAttemptsKey, 0);
      await prefs.remove(_decoyActivatedAtKey);
      if (!isDisposed) notifyListeners();
      return true;
    } else {
      _wrongAttempts++;
      await prefs.setInt(_wrongAttemptsKey, _wrongAttempts);
      if (_wrongAttempts >= 3) {
        await prefs.setString(
          _decoyActivatedAtKey,
          DateTime.now().toIso8601String(),
        );
      }
      if (!isDisposed) notifyListeners();
      return false;
    }
  }

  Future<void> lock() async {
    _isUnlocked = false;
    _wrongAttempts = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wrongAttemptsKey, 0);
    await prefs.remove(_decoyActivatedAtKey);
    if (!isDisposed) notifyListeners();
  }

  Future<void> resetDecoy() async {
    _wrongAttempts = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wrongAttemptsKey, 0);
    await prefs.remove(_decoyActivatedAtKey);
    if (!isDisposed) notifyListeners();
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
      _localMutations.add(photoId);
      final fileName = 'vault_$photoId.jpg';
      final newPath = '${directory.path}/$fileName';
      await File(picked.path).copy(newPath);

      final newItem = VaultItem(
        id: photoId,
        type: VaultItemType.photo,
        imagePath: newPath,
      );

      if (coupleId != null) {
        try {
          final file = File(picked.path);
          final storagePath = 'couples/$coupleId/vault_photos/$photoId.jpg';
          await Supabase.instance.client.storage
              .from(StorageBuckets.vaultPhotos)
              .upload(
                storagePath,
                file,
                fileOptions: const FileOptions(upsert: true),
              );

          await Supabase.instance.client.from('vault_items').upsert({
            'id': photoId,
            'couple_id': coupleId,
            'type': VaultItemType.photo.index,
            // The storage PATH, not a URL. The bucket is private, so the image
            // is rendered through StorageImage, which signs this on demand.
            'image_url': storagePath,
            'created_at': DateTime.now().toIso8601String(),
          });
          NotificationService().sendPartnerNotification(
            title: 'Vault Updated 🔒',
            body: 'A new item was added to the shared Vault',
            feature: 'vault',
            itemId: photoId,
          );
        } catch (e) {
          debugPrint('VaultProvider.addPhoto Supabase upload error: $e');
          _items.insert(0, newItem);
          await _persist();
        }
      } else {
        _items.insert(0, newItem);
        await _persist();
      }

      await RecentActivityService.instance.logActivity(
        activityType: 'created',
        title: 'Added vault item 🔒',
        description: 'Added a new secure item to the Vault',
        icon: '🔒',
        referenceId: photoId,
        route: 'vault',
      );
    } catch (e, st) {
      debugPrint('VaultProvider.addPhoto failed: $e\n$st');
    }
  }

  Future<void> addLetter(String content) async {
    if (!_isUnlocked) return;
    final item = VaultItem(type: VaultItemType.letter, content: content);
    _localMutations.add(item.id);

    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('vault_items').upsert({
          'id': item.id,
          'couple_id': coupleId,
          'type': VaultItemType.letter.index,
          'content': content,
          'created_at': DateTime.now().toIso8601String(),
        });
        NotificationService().sendPartnerNotification(
          title: 'Vault Updated 🔒',
          body: 'A new item was added to the shared Vault',
          feature: 'vault',
          itemId: item.id,
        );
      } catch (e) {
        debugPrint('VaultProvider.addLetter Supabase error: $e');
        _items.insert(0, item);
        await _persist();
      }
    } else {
      _items.insert(0, item);
      await _persist();
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Added vault item 🔒',
      description: 'Added a new secure item to the Vault',
      icon: '🔒',
      referenceId: item.id,
      route: 'vault',
    );
  }

  Future<void> deleteItem(String id) async {
    _localMutations.add(id);
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

    if (coupleId != null) {
      try {
        await Supabase.instance.client
            .from('vault_items')
            .delete()
            .eq('id', id);

        if (item.type == VaultItemType.photo) {
          try {
            final storagePath = 'couples/$coupleId/vault_photos/$id.jpg';
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

    await RecentActivityService.instance.logActivity(
      activityType: 'deleted',
      title: 'Removed vault item 🔒',
      description: 'Removed a secure item from the Vault',
      icon: '🔒',
      referenceId: id,
      route: 'vault',
    );
  }

  Future<void> _persist() async {
    await _persistLocalOnly();
    if (!isDisposed) notifyListeners();
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
    super.dispose();
  }
}
