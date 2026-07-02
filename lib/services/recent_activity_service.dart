import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:days_together/models/local_activity_model.dart';

class RecentActivityService {
  RecentActivityService._privateConstructor();
  static final RecentActivityService instance = RecentActivityService._privateConstructor();

  Database? _database;
  final ValueNotifier<List<LocalActivity>> activitiesNotifier = ValueNotifier<List<LocalActivity>>([]);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'days_together_local.db');
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
        orderBy: 'timestamp DESC',
        limit: 200,
      );
      activitiesNotifier.value = maps.map((m) => LocalActivity.fromMap(m)).toList();
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

      // 2. Fetch all and enforce the 200-item limit in the DB
      final List<Map<String, dynamic>> allMaps = await db.query(
        'local_activities',
        orderBy: 'timestamp DESC',
      );

      List<LocalActivity> list = allMaps.map((m) => LocalActivity.fromMap(m)).toList();

      if (list.length > 200) {
        final cutoffTimeStr = list[199].timestamp.toIso8601String();
        await db.delete(
          'local_activities',
          where: 'timestamp < ?',
          whereArgs: [cutoffTimeStr],
        );
        list = list.take(200).toList();
      }

      activitiesNotifier.value = list;
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
