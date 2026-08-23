import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/features/vault/vault_state.dart';
import 'package:days_together/models/vault_item_model.dart';
import 'package:days_together/services/encrypted_storage_service.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/permission_service.dart';
import 'package:days_together/services/recent_activity_service.dart';
import 'package:days_together/services/storage_url_service.dart';

/// Riverpod port of `VaultProvider` (Phase 6a of the architecture
/// migration). Faithful behavior port: `addPhoto`/`addLetter`/`deleteItem`
/// do not apply locally on the Supabase success path (matching units 2-4,
/// not `BucketListController`'s pattern), and the PIN storage migration
/// (SharedPreferences -> `FlutterSecureStorage`, with a fallback prefs key
/// if secure storage write/read fails) is copied verbatim.
///
/// **Auto-lock on app pause**, previously done via `WidgetsBindingObserver`
/// mixed into the `ChangeNotifier`, is ported the same way: this class also
/// implements `WidgetsBindingObserver`, registers itself in [build] via
/// `WidgetsBinding.instance.addObserver(this)`, and unregisters via
/// `ref.onDispose`.
///
/// **Known, pre-existing self-gating gap, preserved as-is:** [VaultState]'s
/// `photos`/`letters` getters (like the original's) are *not* gated by
/// `isUnlocked` -- only `visibleItems` is. The sole call site
/// (`vault_screen.dart`) never reaches `photos`/`letters` without its own
/// top-level `isUnlocked` early return first, so this has never been a live
/// leak, but any *future* consumer of `photos`/`letters` must remember to
/// check `isUnlocked` itself. Not fixed here -- Phase 6a is a faithful
/// behavior port, not a security hardening pass, and changing this model's
/// contract without touching its one call site could silently create a
/// footgun for whoever eventually converts `vault_screen.dart`.
class VaultController extends Notifier<VaultState>
    with SupabaseLifecycleNotifier<VaultState>, WidgetsBindingObserver {
  static const String _storageKey = 'vault_items';
  static const String _pinKey = 'vault_pin';
  static const String _hasPinKey = 'vault_has_pin';
  static const String _wrongAttemptsKey = 'vault_wrong_attempts';
  static const String _decoyActivatedAtKey = 'vault_decoy_activated_at';
  static const _secureStorage = FlutterSecureStorage();

  final ImagePicker _picker = ImagePicker();
  final Set<String> _localMutations = {};

  @override
  String get tableName => 'vault_items';

  @override
  VaultState build() {
    initSessionLifecycle();
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    _loadState();
    return const VaultState();
  }

  // Named `state` to match WidgetsBindingObserver's own signature and avoid
  // the analyzer's parameter-name lint; this shadows Notifier's `state`
  // getter for this method's body only, which is fine since the method
  // doesn't need to read it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      lock();
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

  VaultItem _parseItem(Map<String, dynamic> data, {String? imagePath}) {
    final typeIndex = data['type'] as int? ?? 0;
    final type =
        (typeIndex >= 0 && typeIndex < VaultItemType.values.length) ? VaultItemType.values[typeIndex] : VaultItemType.photo;
    return VaultItem(
      id: data['id'] as String,
      type: type,
      content: data['content'] as String?,
      imagePath: imagePath,
      // Must match the column addPhoto writes and the realtime handler
      // reads -- this previously read 'network_image_url', a column
      // nothing writes, so server-synced vault photos lost their image on
      // every cold start until a realtime event happened to arrive. Fixed
      // upstream in VaultProvider before this port; preserved as fixed.
      imageUrl: data['image_url'] as String?,
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'] as String) : DateTime.now(),
    );
  }

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    try {
      final List<dynamic> res = await Supabase.instance.client.from('vault_items').select().eq('couple_id', coupleId!);
      final parsed = res.map((data) => _parseItem(data)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!ref.mounted) return;
      state = state.copyWith(items: parsed, isLoading: false);
      await _persistLocalOnly();
    } catch (e) {
      debugPrint('VaultController.syncInitialData error: $e');
    }
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    if (!ref.mounted) return;
    final incoming = dataList.map((data) => _parseItem(data)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
          title: 'Partner added vault item 🔒',
          description: 'Added a new secure item to the Vault',
          icon: '🔒',
          referenceId: item.id,
          route: 'vault',
        );
      }

      final deleted = oldItems.where((old) => !incoming.any((inc) => inc.id == old.id)).toList();
      for (final item in deleted) {
        if (_localMutations.contains(item.id)) {
          _localMutations.remove(item.id);
          continue;
        }
        RecentActivityService.instance.logActivity(
          activityType: 'deleted',
          title: 'Partner removed vault item 🔒',
          description: 'Removed a secure item from the Vault',
          icon: '🔒',
          referenceId: item.id,
          route: 'vault',
        );
      }
    }

    state = state.copyWith(items: incoming, isLoading: false);
    _persistLocalOnly();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('VaultController: Supabase sync error: $error');
    _loadItemsFromCache();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPin = prefs.getBool(_hasPinKey) ?? false;

      var wrongAttempts = prefs.getInt(_wrongAttemptsKey) ?? 0;
      final decoyTimeStr = prefs.getString(_decoyActivatedAtKey);
      if (decoyTimeStr != null) {
        final decoyTime = DateTime.parse(decoyTimeStr);
        final diff = DateTime.now().difference(decoyTime);
        if (diff.inMinutes >= 10) {
          wrongAttempts = 0;
          await prefs.setInt(_wrongAttemptsKey, 0);
          await prefs.remove(_decoyActivatedAtKey);
        }
      }

      var resolvedHasPin = hasPin;
      try {
        final storedSharedPin = prefs.getString(_pinKey);
        if (storedSharedPin != null) {
          try {
            await _secureStorage.write(key: _pinKey, value: storedSharedPin);
            await prefs.remove(_pinKey);
          } catch (e) {
            debugPrint('Secure storage write failed during migration: $e. Falling back.');
            await prefs.setString(PrefsKeys.vaultPinFallback, storedSharedPin);
          }
          resolvedHasPin = true;
          await prefs.setBool(_hasPinKey, true);
        } else {
          String? securePin;
          try {
            securePin = await _secureStorage.read(key: _pinKey);
          } catch (e) {
            debugPrint('Secure storage read failed: $e. Using fallback.');
            securePin = prefs.getString(PrefsKeys.vaultPinFallback);
          }
          resolvedHasPin = securePin != null && securePin.isNotEmpty;
          await prefs.setBool(_hasPinKey, resolvedHasPin);
        }
      } catch (e) {
        debugPrint('Secure storage migration wrapper error: $e');
      }

      if (!ref.mounted) return;
      state = state.copyWith(hasPin: resolvedHasPin, wrongAttempts: wrongAttempts);
      await _loadItemsFromCache();
    } catch (e, st) {
      debugPrint('VaultController._loadState failed: $e\n$st');
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> _loadItemsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      final items = jsonString != null
          ? ((jsonDecode(jsonString) as List).map((j) => VaultItem.fromJson(j)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          : <VaultItem>[];
      if (!ref.mounted) return;
      state = state.copyWith(items: items);
    } catch (e, st) {
      debugPrint('VaultController._loadItemsFromCache failed: $e\n$st');
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
    if (!ref.mounted) return;
    state = state.copyWith(hasPin: true, isUnlocked: true);
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
      await prefs.setInt(_wrongAttemptsKey, 0);
      await prefs.remove(_decoyActivatedAtKey);
      if (!ref.mounted) return true;
      state = state.copyWith(isUnlocked: true, wrongAttempts: 0);
      return true;
    } else {
      final nextAttempts = state.wrongAttempts + 1;
      await prefs.setInt(_wrongAttemptsKey, nextAttempts);
      if (nextAttempts >= 3) {
        await prefs.setString(_decoyActivatedAtKey, DateTime.now().toIso8601String());
      }
      if (!ref.mounted) return false;
      state = state.copyWith(wrongAttempts: nextAttempts);
      return false;
    }
  }

  Future<void> lock() async {
    state = state.copyWith(isUnlocked: false, wrongAttempts: 0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wrongAttemptsKey, 0);
    await prefs.remove(_decoyActivatedAtKey);
  }

  Future<void> resetDecoy() async {
    state = state.copyWith(wrongAttempts: 0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wrongAttemptsKey, 0);
    await prefs.remove(_decoyActivatedAtKey);
  }

  Future<void> addPhoto(BuildContext context) async {
    if (!state.isUnlocked) return;
    final hasPermission = await PermissionService().requestPhotosPermission(context);
    if (!hasPermission) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (picked == null) return;
      if (!ref.mounted) return;
      final directory = await getApplicationDocumentsDirectory();
      final photoId = const Uuid().v4();
      _localMutations.add(photoId);
      final fileName = 'vault_$photoId.jpg';
      final newPath = '${directory.path}/$fileName';
      await File(picked.path).copy(newPath);
      if (!ref.mounted) return;

      final newItem = VaultItem(id: photoId, type: VaultItemType.photo, imagePath: newPath);

      if (coupleId != null) {
        try {
          final storagePath = 'couples/$coupleId/vault_photos/$photoId.jpg';
          await EncryptedStorageService.instance.encryptAndUpload(
            bucket: StorageBuckets.vaultPhotos,
            storagePath: storagePath,
            plaintext: await File(picked.path).readAsBytes(),
          );

          await Supabase.instance.client.from('vault_items').upsert({
            'id': photoId,
            'couple_id': coupleId,
            'type': VaultItemType.photo.index,
            // The storage PATH, not a URL. The bucket is private, so the
            // image is rendered through StorageImage, which signs this on
            // demand.
            'image_url': storagePath,
            'created_at': DateTime.now().toIso8601String(),
          });
          NotificationService().sendPartnerNotification(
            title: 'Vault Updated 🔒',
            body: 'A new item was added to the shared Vault',
            feature: 'vault',
            itemId: photoId,
          );
          // No local apply on success, matching the original.
        } catch (e) {
          debugPrint('VaultController.addPhoto Supabase upload error: $e');
          if (!ref.mounted) return;
          state = state.copyWith(items: [newItem, ...state.items]);
          await _persist();
        }
      } else {
        state = state.copyWith(items: [newItem, ...state.items]);
        await _persist();
      }

      if (!ref.mounted) return;
      await RecentActivityService.instance.logActivity(
        activityType: 'created',
        title: 'Added vault item 🔒',
        description: 'Added a new secure item to the Vault',
        icon: '🔒',
        referenceId: photoId,
        route: 'vault',
      );
    } catch (e, st) {
      debugPrint('VaultController.addPhoto failed: $e\n$st');
    }
  }

  Future<void> addLetter(String content) async {
    if (!state.isUnlocked) return;
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
        debugPrint('VaultController.addLetter Supabase error: $e');
        if (!ref.mounted) return;
        state = state.copyWith(items: [item, ...state.items]);
        await _persist();
      }
    } else {
      state = state.copyWith(items: [item, ...state.items]);
      await _persist();
    }

    if (!ref.mounted) return;
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
    final index = state.items.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final item = state.items[index];

    if (item.imagePath != null) {
      try {
        final file = File(item.imagePath!);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('VaultController: Failed to delete file: $e');
      }
    }

    if (coupleId != null) {
      try {
        await Supabase.instance.client.from('vault_items').delete().eq('id', id);

        if (item.type == VaultItemType.photo) {
          try {
            final storagePath = 'couples/$coupleId/vault_photos/$id.jpg';
            await Supabase.instance.client.storage.from('vault-photos').remove([storagePath]);
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('VaultController.deleteItem Supabase error: $e');
        if (!ref.mounted) return;
        state = state.copyWith(items: state.items.where((i) => i.id != id).toList());
        await _persist();
      }
    } else {
      state = state.copyWith(items: state.items.where((i) => i.id != id).toList());
      await _persist();
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'deleted',
      title: 'Removed vault item 🔒',
      description: 'Removed a secure item from the Vault',
      icon: '🔒',
      referenceId: id,
      route: 'vault',
    );
  }

  Future<void> _persist() => _persistLocalOnly();

  Future<void> _persistLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.items.map((i) => i.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('VaultController._persistLocalOnly failed: $e\n$st');
    }
  }
}

final vaultControllerProvider = NotifierProvider.autoDispose<VaultController, VaultState>(
  VaultController.new,
  dependencies: [coupleSessionProvider],
);
