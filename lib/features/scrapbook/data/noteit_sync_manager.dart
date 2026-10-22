import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/shared/models/noteit_model.dart';
import 'package:days_together/core/storage/encrypted_storage_service.dart';
import 'package:days_together/core/notifications/notification_service.dart';
import 'package:days_together/core/storage/storage_url_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:days_together/core/constants/tables.dart';

class NoteitSyncTask {
  final String id;
  final NoteitType type;
  final String? content;
  final String? imagePath;
  final Color? backgroundColor;
  final DateTime createdAt;
  int retryCount;
  String status; // 'pending' | 'syncing' | 'failed'

  NoteitSyncTask({
    required this.id,
    required this.type,
    this.content,
    this.imagePath,
    this.backgroundColor,
    required this.createdAt,
    this.retryCount = 0,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'content': content,
    'imagePath': imagePath,
    'backgroundColor': backgroundColor?.toARGB32(),
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'status': status,
  };

  factory NoteitSyncTask.fromJson(Map<String, dynamic> json) {
    final typeIndex = json['type'] as int? ?? 0;
    return NoteitSyncTask(
      id: json['id'] as String,
      type: (typeIndex >= 0 && typeIndex < NoteitType.values.length)
          ? NoteitType.values[typeIndex]
          : NoteitType.drawing,
      content: json['content'] as String?,
      imagePath: json['imagePath'] as String?,
      backgroundColor: json['backgroundColor'] != null
          ? Color(json['backgroundColor'] as int)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
    );
  }
}

/// What [NoteitSyncManager] needs from its owner: the credentials to upload
/// under, and a sink for per-item status. `NoteitController` implements it;
/// taking the interface rather than the controller keeps `data/` from
/// importing the feature's controller (which imports `data/`).
abstract interface class NoteitSyncHost {
  String? get coupleId;
  String? get sessionUserId;
  void updateItemSyncStatus(String id, SyncStatus status);
}

class NoteitSyncManager {
  static const String _queueKey = 'noteit_sync_queue';
  static final NoteitSyncManager instance = NoteitSyncManager._internal();

  NoteitSyncManager._internal({
    Stream<List<ConnectivityResult>> Function()? connectivityChanges,
    Future<bool> Function()? isOnline,
  }) : _connectivityChanges = connectivityChanges,
       _isOnline = isOnline;

  /// A private instance with the connectivity plugin replaced, so tests
  /// never touch its platform channels.
  @visibleForTesting
  factory NoteitSyncManager.forTest({
    Stream<List<ConnectivityResult>> Function()? connectivityChanges,
    Future<bool> Function()? isOnline,
  }) => NoteitSyncManager._internal(
    connectivityChanges: connectivityChanges ?? () => const Stream.empty(),
    isOnline: isOnline ?? () async => false,
  );

  final Stream<List<ConnectivityResult>> Function()? _connectivityChanges;
  final Future<bool> Function()? _isOnline;

  NoteitSyncHost? _provider;

  /// The couple the in-memory [_queue] belongs to. The queue is never
  /// carried across a couple change: SessionDataWiper removes the persisted
  /// copy on unlink/logout, and this singleton outlives both, so without
  /// the reset the previous relationship's pending notes would upload into
  /// the next one (and be written back to prefs by the next save).
  String? _coupleId;

  /// Bumped whenever [_queue] is replaced wholesale, so an in-flight load or
  /// sync loop started for the previous queue stops touching it.
  int _generation = 0;
  Future<void> _loaded = Future.value();

  List<NoteitSyncTask> _queue = [];
  bool _isSyncing = false;
  Timer? _backoffTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool get hasPendingItems => _queue.isNotEmpty;
  List<NoteitSyncTask> get queue => List.unmodifiable(_queue);

  /// Binds the queue to [provider]'s current couple and loads it. Called on
  /// every session change, so it is a no-op unless the owner or the couple
  /// actually changed -- reloading would replace [_queue] under a concurrent
  /// [enqueue] or [triggerSync].
  Future<void> initialize(NoteitSyncHost provider) {
    final coupleId = provider.coupleId;
    if (identical(provider, _provider) && coupleId == _coupleId) {
      return _loaded;
    }
    _provider = provider;
    if (coupleId != _coupleId) {
      _clearQueue();
      _coupleId = coupleId;
      _loaded = _loadQueue(_generation);
    }
    _startConnectivityCheck();
    return _loaded;
  }

  /// Drops all in-memory state. Called when the owning controller purges
  /// (disconnect/logout); the persisted queue is SessionDataWiper's job.
  void reset() {
    _clearQueue();
    _provider = null;
    _coupleId = null;
    _loaded = Future.value();
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  void _clearQueue() {
    _generation++;
    _backoffTimer?.cancel();
    _backoffTimer = null;
    _queue = [];
  }

  Future<void> _loadQueue(int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _generation) return;
      final jsonString = prefs.getString(_queueKey);
      if (jsonString == null) {
        _queue = [];
        return;
      }
      final List<dynamic> jsonList = jsonDecode(jsonString) as List;
      _queue =
          jsonList
              .map((j) => NoteitSyncTask.fromJson(Map<String, dynamic>.from(j)))
              .toList()
            // Sort chronologically (oldest first)
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      // 'syncing' is only true while this process's sync loop holds the
      // task. Loaded from disk it means the app died mid-upload; the loop
      // skips 'syncing' tasks, so leaving it would strand the note forever
      // (and the history panel only offers Retry for failed ones).
      for (final task in _queue) {
        if (task.status == 'syncing') task.status = 'pending';
      }
    } catch (e) {
      debugPrint('NoteitSyncManager: Failed to load queue: $e');
    }
  }

  Future<void> _saveQueue() async {
    final generation = _generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _generation) return;
      final jsonList = _queue.map((t) => t.toJson()).toList();
      await prefs.setString(_queueKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('NoteitSyncManager: Failed to save queue: $e');
    }
  }

  Future<void> enqueue(NoteitSyncTask task) async {
    // A load still in flight would replace _queue and drop this task.
    await _loaded;

    // Prevent duplicate task ID enqueuing
    if (_queue.any((t) => t.id == task.id)) return;

    _queue.add(task);
    await _saveQueue();
    _provider?.updateItemSyncStatus(task.id, SyncStatus.sending);
    triggerSync();
  }

  Future<void> retryTask(String taskId) async {
    await _loaded;
    final taskIndex = _queue.indexWhere((t) => t.id == taskId);
    if (taskIndex != -1) {
      _queue[taskIndex].status = 'pending';
      _queue[taskIndex].retryCount = 0;
      await _saveQueue();
      _provider?.updateItemSyncStatus(taskId, SyncStatus.sending);
      triggerSync();
    }
  }

  void _startConnectivityCheck() {
    _connectivitySub?.cancel();
    final changes =
        _connectivityChanges?.call() ?? Connectivity().onConnectivityChanged;
    _connectivitySub = changes.listen((results) async {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && hasPendingItems && !_isSyncing) {
        triggerSync();
      }
    });
  }

  Future<bool> checkConnection() async {
    final isOnline = _isOnline;
    if (isOnline != null) return isOnline();
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<void> triggerSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    final generation = _generation;

    try {
      final coupleId = _coupleId;
      final userId = _provider?.sessionUserId;

      if (coupleId == null ||
          userId == null ||
          _provider?.coupleId != coupleId) {
        _isSyncing = false;
        return;
      }

      // Process tasks sequentially (one at a time, oldest first). After each
      // await, a changed generation means the queue was reset or rebound to
      // another couple: stop rather than index into a list this loop no
      // longer owns.
      for (int i = 0; i < _queue.length; i++) {
        final task = _queue[i];

        if (task.status == 'syncing') continue;
        if (task.retryCount >= 5) {
          task.status = 'failed';
          _provider?.updateItemSyncStatus(task.id, SyncStatus.failed);
          continue;
        }

        // Check connection before processing each task
        final isOnline = await checkConnection();
        if (generation != _generation) break;
        if (!isOnline) {
          _scheduleBackoff(task);
          break; // Stop sync loop if offline
        }

        task.status = 'syncing';
        await _saveQueue();

        final success = await _executeTask(task, coupleId, userId);
        if (generation != _generation) break;

        if (success) {
          // Clean up local persistent file if any to prevent storage leaks
          if (task.imagePath != null) {
            try {
              final file = File(task.imagePath!);
              if (await file.exists()) {
                await file.delete();
                debugPrint(
                  'NoteitSyncManager: Cleaned up local draft file: ${task.imagePath}',
                );
              }
            } catch (e) {
              debugPrint(
                'NoteitSyncManager: Failed to delete local draft file: $e',
              );
            }
          }
          if (generation != _generation) break;

          _queue.removeAt(i);
          i--; // Adjust index after removal
          await _saveQueue();
          _provider?.updateItemSyncStatus(task.id, SyncStatus.synced);
        } else {
          task.retryCount++;
          if (task.retryCount >= 5) {
            task.status = 'failed';
            _queue[i].status = 'failed';
            await _saveQueue();
            _provider?.updateItemSyncStatus(task.id, SyncStatus.failed);
            // Do NOT break the loop here! Let other tasks continue
          } else {
            task.status = 'pending';
            _queue[i].status = 'pending';
            await _saveQueue();
            _provider?.updateItemSyncStatus(task.id, SyncStatus.failed);

            // Schedule backoff and stop queue processing to preserve chronological FIFO ordering (Audit 5.2)
            _scheduleBackoff(task);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('NoteitSyncManager: triggerSync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  void _scheduleBackoff(NoteitSyncTask task) {
    _backoffTimer?.cancel();

    // Exponential backoff configuration
    // Attempt 1 -> 5 seconds
    // Attempt 2 -> 30 seconds
    // Attempt 3 -> 120 seconds (2 mins)
    // Attempt 4 -> 300 seconds (5 mins)
    int backoffSeconds = 5;
    if (task.retryCount == 1) {
      backoffSeconds = 30;
    } else if (task.retryCount == 2) {
      backoffSeconds = 120;
    } else if (task.retryCount >= 3) {
      backoffSeconds = 300;
    }

    debugPrint(
      'NoteitSyncManager: Scheduling retry backoff of $backoffSeconds seconds...',
    );
    _backoffTimer = Timer(Duration(seconds: backoffSeconds), () {
      triggerSync();
    });
  }

  Future<bool> _executeTask(
    NoteitSyncTask task,
    String coupleId,
    String userId,
  ) async {
    try {
      // Holds the storage PATH, not a URL: the bucket is private, so the image
      // is rendered through StorageImage, which signs the path on demand.
      String? imageRef;

      // Handle file uploads for any task with local image path
      if (task.imagePath != null) {
        final file = File(task.imagePath!);
        if (!await file.exists()) {
          // Unrecoverable error: local file deleted
          debugPrint(
            'NoteitSyncManager: Local file for task ${task.id} does not exist.',
          );
          return false;
        }

        final storagePath = 'couples/$coupleId/love_notes/${task.id}.jpg';
        await EncryptedStorageService.instance.encryptAndUpload(
          bucket: StorageBuckets.loveNotes,
          storagePath: storagePath,
          plaintext: await file.readAsBytes(),
        );

        imageRef = storagePath;
      }

      final typeStr = task.type == NoteitType.drawing
          ? 'drawing'
          : task.type == NoteitType.photo
          ? 'photo'
          : 'text';

      // Safe atomic insert/upsert (idempotency key is the task.id)
      await Supabase.instance.client.from(Tables.loveNotes).upsert({
        'id': task.id,
        'couple_id': coupleId,
        'type': typeStr,
        'content': task.content,
        'image_url': imageRef,
        'sender_id': userId,
        'created_at': task.createdAt.toIso8601String(),
        'background_color': task.backgroundColor?.toARGB32().toSigned(32),
      });

      final feature = task.type == NoteitType.drawing
          ? 'doodle_notes'
          : 'love_notes';
      final title = task.type == NoteitType.drawing
          ? 'New Doodle 🎨'
          : task.type == NoteitType.photo
          ? 'New Photo Note 📷'
          : 'New Love Note ✍️';
      final body = task.type == NoteitType.drawing
          ? 'Your partner sent you a new doodle!'
          : task.type == NoteitType.photo
          ? 'Your partner shared a new photo note!'
          : 'Your partner sent you a new love note!';

      NotificationService().sendPartnerNotification(
        title: title,
        body: body,
        feature: feature,
        itemId: task.id,
      );

      return true;
    } on PostgrestException catch (e) {
      // Differentiate errors: recoverable vs non-recoverable
      final code = e.code;
      if (code == '42501' ||
          code?.startsWith('23') == true ||
          code == '400' ||
          code == '403') {
        debugPrint('NoteitSyncManager: Non-recoverable database error: $e');
        task.retryCount = 5; // Forces failure without retrying
      }
      return false;
    } on StorageException catch (e) {
      // Storage failures surface as StorageException, NOT PostgrestException,
      // so without this branch an RLS denial fell through to the generic catch
      // below and retried forever with backoff.
      final code = e.statusCode;
      if (code == '400' || code == '403' || code == '42501') {
        debugPrint(
          'NoteitSyncManager: Non-recoverable storage error: ${e.message}',
        );
        task.retryCount = 5; // Forces failure without retrying
      } else {
        debugPrint(
          'NoteitSyncManager: Recoverable storage error: ${e.message}',
        );
      }
      return false;
    } catch (e) {
      debugPrint('NoteitSyncManager: Recoverable upload error: $e');
      return false;
    }
  }

  void cancel() {
    _backoffTimer?.cancel();
    _connectivitySub?.cancel();
  }
}
