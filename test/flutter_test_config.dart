// Applies to every test under test/ (flutter_test's global config hook).
//
// Gives tests a real SQLite: RecentActivityService used to fail its database
// open in every test run ("databaseFactory not initialized"), which both
// spammed the output and left its real behaviour -- including the
// clearAll() SessionDataWiper relies on -- untestable. Each test file runs in
// its own isolate, and the database is in-memory, so nothing persists
// between files or touches the disk.

import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:days_together/core/activity/recent_activity_service.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  RecentActivityService.databasePathOverride = inMemoryDatabasePath;
  await testMain();
}
