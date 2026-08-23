import 'package:flutter/foundation.dart';
import 'package:days_together/services/home_widget_service.dart';
import 'package:days_together/services/storage_url_service.dart';

/// Standard interface for relationship lifecycle observers.
abstract class RelationshipLifecycleAware {
  Future<void> onPair(String coupleId, String userId);
  Future<void> onRepair(String coupleId, String userId);
  Future<void> onDisconnect();
  Future<void> onLogout();
  Future<void> purgeCache();
  Future<void> syncInitialData();
  void initRealtime();
  void disposeRealtime();
}

/// Centralized manager to coordinate lifecycle transitions across the app.
class RelationshipLifecycleManager {
  static final RelationshipLifecycleManager instance = RelationshipLifecycleManager._();
  RelationshipLifecycleManager._();

  final List<RelationshipLifecycleAware> _listeners = [];

  void register(RelationshipLifecycleAware listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void unregister(RelationshipLifecycleAware listener) {
    _listeners.remove(listener);
  }

  Future<void> handlePair(String coupleId, String userId) async {
    debugPrint('RelationshipLifecycleManager: Coordinating Pair event...');
    for (final listener in _listeners) {
      try {
        await listener.onPair(coupleId, userId);
      } catch (e, st) {
        debugPrint('RelationshipLifecycleManager: Listener onPair error: $e\n$st');
      }
    }
  }

  Future<void> handleRepair(String coupleId, String userId) async {
    debugPrint('RelationshipLifecycleManager: Coordinating Repair event...');
    for (final listener in _listeners) {
      try {
        await listener.onRepair(coupleId, userId);
      } catch (e, st) {
        debugPrint('RelationshipLifecycleManager: Listener onRepair error: $e\n$st');
      }
    }
  }

  Future<void> handleDisconnect() async {
    debugPrint('RelationshipLifecycleManager: Coordinating Disconnect event...');
    await HomeWidgetService.instance.clearWidget();
    // Drop every signed storage URL so a link to the previous couple's objects
    // cannot be reused after the relationship ends.
    StorageUrlService.instance.clearAll();
    for (final listener in _listeners) {
      try {
        await listener.onDisconnect();
      } catch (e, st) {
        debugPrint('RelationshipLifecycleManager: Listener onDisconnect error: $e\n$st');
      }
    }
  }

  Future<void> handleLogout() async {
    debugPrint('RelationshipLifecycleManager: Coordinating Logout event...');
    await HomeWidgetService.instance.clearWidget();
    StorageUrlService.instance.clearAll();
    for (final listener in _listeners) {
      try {
        await listener.onLogout();
      } catch (e, st) {
        debugPrint('RelationshipLifecycleManager: Listener onLogout error: $e\n$st');
      }
    }
  }
}
