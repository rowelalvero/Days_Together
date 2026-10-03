import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:days_together/shared/models/local_activity_model.dart';

class RecentActivityService {
  RecentActivityService._privateConstructor();
  static final RecentActivityService instance =
      RecentActivityService._privateConstructor();

  Database? _database;

  static const int _maxEntries = 200;

  /// Insertion order breaks timestamp ties, so two entries logged in the
  /// same instant always come back in the order they were logged.
  static const String _newestFirst = 'timestamp DESC, rowid DESC';

  /// Test-only: open this path instead of the on-device database file (the
  /// test harness sets sqflite's in-memory path -- see
  /// test/flutter_test_config.dart).
  @visibleForTesting
  static String? databasePathOverride;
  final ValueNotifier<List<LocalActivity>> activitiesNotifier =
      ValueNotifier<List<LocalActivity>>([]);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path =
        databasePathOverride ??
        join(await getDatabasesPath(), 'days_together_local.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE local_activities (
            id TEXT PRIMARY KEY,
            activity_type TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            icon TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            reference_id TEXT,
            route TEXT,
            initiated_by_current_user INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_local_activities_timestamp 
          ON local_activities (timestamp DESC)
        ''');
      },
    );
  }

  Future<void> init() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'local_activities',
        orderBy: _newestFirst,
        limit: _maxEntries,
      );
      activitiesNotifier.value = maps
          .map((m) => LocalActivity.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('RecentActivityService: init error: $e');
    }
  }

  Future<void> logActivity({
    required String activityType,
    required String title,
    required String description,
    required String icon,
    String? referenceId,
    String? route,
    bool initiatedByCurrentUser = true,
  }) async {
    try {
      final db = await database;
      final activity = LocalActivity(
        id: const Uuid().v4(),
        activityType: activityType,
        title: title,
        description: description,
        icon: icon,
        timestamp: DateTime.now(),
        referenceId: referenceId,
        route: route,
        initiatedByCurrentUser: initiatedByCurrentUser,
      );

      // 1. Insert the new activity
      await db.insert(
        'local_activities',
        activity.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Keep only the newest entries, in one statement. This used to read
      // and parse the whole table on every insert and delete by
      // `timestamp < cutoff`, which kept the wrong rows when two entries
      // shared a timestamp.
      await db.rawDelete(
        'DELETE FROM local_activities WHERE rowid NOT IN '
        '(SELECT rowid FROM local_activities ORDER BY $_newestFirst LIMIT ?)',
        [_maxEntries],
      );
      final List<Map<String, dynamic>> maps = await db.query(
        'local_activities',
        orderBy: _newestFirst,
      );
      activitiesNotifier.value = maps
          .map((m) => LocalActivity.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('RecentActivityService: logActivity error: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      final db = await database;
      await db.delete('local_activities');
      activitiesNotifier.value = [];
    } catch (e) {
      debugPrint('RecentActivityService: clearAll error: $e');
    }
  }
}
