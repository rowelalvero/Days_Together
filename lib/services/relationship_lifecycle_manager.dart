import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:days_together/services/realtime_subscription_manager.dart';
import 'package:days_together/services/home_widget_service.dart';
import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/providers/couple_session.dart';

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

/// Abstract base provider for relationship lifecycle awareness without realtime subscriptions.
abstract class RelationshipLifecycleProvider extends ChangeNotifier implements RelationshipLifecycleAware {
  String? _coupleId;
  String? _userId;
  bool _disposed = false;

  String? get coupleId => _coupleId;
  String? get userId => _userId;
  bool get isDisposed => _disposed;

  RelationshipLifecycleProvider() {
    RelationshipLifecycleManager.instance.register(this);
  }

  /// Safety timeout for syncInitialData to prevent infinite loading.
  static const _syncTimeout = Duration(seconds: 15);

  @override
  Future<void> onPair(String coupleId, String userId) async {
    _coupleId = coupleId;
    _userId = userId;
    try {
      await syncInitialData().timeout(_syncTimeout);
    } on TimeoutException {
      debugPrint('$runtimeType: syncInitialData timed out after ${_syncTimeout.inSeconds}s');
    }
  }

  @override
  Future<void> onRepair(String coupleId, String userId) async {
    await onPair(coupleId, userId);
  }

  @override
  Future<void> onDisconnect() async {
    _coupleId = null;
    _userId = null;
    await purgeCache();
  }

  @override
  Future<void> onLogout() async {
    await onDisconnect();
  }

  @override
  void initRealtime() {}

  @override
  void disposeRealtime() {}

  void updateSession(CoupleSession session) {
    final bool credentialsChanged = _coupleId != session.coupleId || _userId != session.userId;

    if (credentialsChanged) {
      _coupleId = session.coupleId;
      _userId = session.userId;

      if (_coupleId != null && _userId != null) {
        syncInitialData().timeout(_syncTimeout, onTimeout: () {
          debugPrint('$runtimeType: syncInitialData timed out after ${_syncTimeout.inSeconds}s');
        });
      } else {
        purgeCache();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    RelationshipLifecycleManager.instance.unregister(this);
    super.dispose();
  }
}

/// Abstract base provider that encapsulates common Supabase realtime and REST lifecycle logic.
abstract class SupabaseLifecycleProvider extends RelationshipLifecycleProvider {
  StreamSubscription? _syncSub;

  String get tableName;
  List<String> get primaryKey => const ['id'];

  SupabaseLifecycleProvider() : super();

  void onRealtimeData(List<Map<String, dynamic>> dataList);
  void onRealtimeError(Object error) {}

  @override
  Future<void> onPair(String coupleId, String userId) async {
    await super.onPair(coupleId, userId);
    disposeRealtime();
    if (hasListeners) {
      initRealtime();
    }
  }

  @override
  Future<void> onDisconnect() async {
    await super.onDisconnect();
    disposeRealtime();
  }

  @override
  void initRealtime() {
    if (coupleId == null) return;
    _syncSub?.cancel();
    _syncSub = RealtimeSubscriptionManager.instance
        .getStream(tableName: tableName, coupleId: coupleId!, primaryKey: primaryKey)
        .listen(
      (dataList) {
        if (!isDisposed) onRealtimeData(dataList);
      },
      onError: (err) {
        if (!isDisposed) onRealtimeError(err);
      },
    );
  }

  @override
  void disposeRealtime() {
    _syncSub?.cancel();
    _syncSub = null;
  }

  @override
  void updateSession(CoupleSession session) {
    final bool credentialsChanged = coupleId != session.coupleId || userId != session.userId;

    if (credentialsChanged) {
      super.updateSession(session);
      disposeRealtime();

      if (coupleId != null && userId != null) {
        if (hasListeners && session.isSupabaseAvailable) {
          initRealtime();
        }
      }
    } else if (session.isSupabaseAvailable && _syncSub == null && hasListeners && coupleId != null) {
      initRealtime();
    }
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (hasListeners && _syncSub == null && coupleId != null) {
      initRealtime();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      disposeRealtime();
    }
  }

  @override
  void dispose() {
    disposeRealtime();
    super.dispose();
  }
}
