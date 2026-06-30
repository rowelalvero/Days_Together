import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/providers/noteit_provider.dart';

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

class NoteitSyncManager {
  static const String _queueKey = 'noteit_sync_queue';
  static final NoteitSyncManager instance = NoteitSyncManager._internal();

  NoteitSyncManager._internal();

  NoteitProvider? _provider;
  List<NoteitSyncTask> _queue = [];
  bool _isSyncing = false;
  Timer? _backoffTimer;
  Timer? _connectivityTimer;
  bool Function()? mockConnectionChecker;

  bool get hasPendingItems => _queue.isNotEmpty;
  bool get isSyncing => _isSyncing;
  List<NoteitSyncTask> get queue => List.unmodifiable(_queue);

  void initialize(NoteitProvider provider) {
    _provider = provider;
    _loadQueue();
    _startConnectivityCheck();
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_queueKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString) as List;
        _queue = jsonList.map((j) => NoteitSyncTask.fromJson(Map<String, dynamic>.from(j))).toList();
        // Sort chronologically (oldest first)
        _queue.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
    } catch (e) {
      debugPrint('NoteitSyncManager: Failed to load queue: $e');
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _queue.map((t) => t.toJson()).toList();
      await prefs.setString(_queueKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('NoteitSyncManager: Failed to save queue: $e');
    }
  }

  Future<void> enqueue(NoteitSyncTask task) async {
    // Prevent duplicate task ID enqueuing
    if (_queue.any((t) => t.id == task.id)) return;
    
    _queue.add(task);
    await _saveQueue();
    _provider?.updateItemSyncStatus(task.id, SyncStatus.sending);
    triggerSync();
  }

  Future<void> retryTask(String taskId) async {
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
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (hasPendingItems && !_isSyncing) {
        final isOnline = await checkConnection();
        if (isOnline) {
          triggerSync();
        }
      }
    });
  }

  Future<bool> checkConnection() async {
    if (mockConnectionChecker != null) {
      return mockConnectionChecker!();
    }
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> triggerSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final coupleId = _provider?.coupleId;
      final userId = _provider?.userId;

      if (coupleId == null || userId == null) {
        _isSyncing = false;
        return;
      }

      // Process tasks sequentially (one at a time, oldest first)
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
        if (!isOnline) {
          _scheduleBackoff(task);
          break; // Stop sync loop if offline
        }

        task.status = 'syncing';
        await _saveQueue();

        final success = await _executeTask(task, coupleId, userId);

        if (success) {
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
          } else {
            task.status = 'pending';
            _queue[i].status = 'pending';
            await _saveQueue();
            _scheduleBackoff(task);
            break; // Stop and wait for backoff
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

    debugPrint('NoteitSyncManager: Scheduling retry backoff of $backoffSeconds seconds...');
    _backoffTimer = Timer(Duration(seconds: backoffSeconds), () {
      triggerSync();
    });
  }

  Future<bool> _executeTask(NoteitSyncTask task, String coupleId, String userId) async {
    try {
      String? imageUrl;

      // Handle file uploads for photo types
      if (task.type == NoteitType.photo && task.imagePath != null) {
        final file = File(task.imagePath!);
        if (!await file.exists()) {
          // Unrecoverable error: local file deleted
          debugPrint('NoteitSyncManager: Local file for task ${task.id} does not exist.');
          return false;
        }

        final storagePath = 'couples/$coupleId/love_notes/${task.id}.jpg';
        await Supabase.instance.client.storage
            .from('love-notes')
            .upload(
              storagePath,
              file,
              fileOptions: const FileOptions(upsert: true), // Idempotency
            );

        imageUrl = Supabase.instance.client.storage
            .from('love-notes')
            .getPublicUrl(storagePath);
      }

      final typeStr = task.type == NoteitType.drawing
          ? 'drawing'
          : task.type == NoteitType.photo
              ? 'photo'
              : 'text';

      // Safe atomic insert/upsert (idempotency key is the task.id)
      await Supabase.instance.client.from('love_notes').upsert({
        'id': task.id,
        'couple_id': coupleId,
        'type': typeStr,
        'content': task.content,
        'image_url': imageUrl,
        'sender_id': userId,
        'created_at': task.createdAt.toIso8601String(),
        'background_color': task.backgroundColor?.toARGB32().toSigned(32),
      });

      return true;
    } on PostgrestException catch (e) {
      // Differentiate errors: recoverable vs non-recoverable
      final code = e.code;
      if (code == '42501' || code?.startsWith('23') == true || code == '400' || code == '403') {
        debugPrint('NoteitSyncManager: Non-recoverable database error: $e');
        task.retryCount = 5; // Forces failure without retrying
      }
      return false;
    } catch (e) {
      debugPrint('NoteitSyncManager: Recoverable upload error: $e');
      return false;
    }
  }

  void cancel() {
    _backoffTimer?.cancel();
    _connectivityTimer?.cancel();
  }
}
