import 'dart:convert';
import 'dart:io';
import 'package:days_together/app/router/app_router.dart';
import 'package:days_together/app/router/route_names.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  /// The host platform, as stored on `user_fcm_tokens.device_type`. Replaces
  /// `Platform.isIOS ? 'ios' : 'android'`, which labelled every desktop,
  /// Linux, and web run as an Android device -- so any per-platform push
  /// routing or analytics built on this column was reading a value that was
  /// simply wrong off-device. `kIsWeb` is tested first because `dart:io`'s
  /// [Platform] throws on web.
  static String get _deviceType {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return Platform.operatingSystem;
  }

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _tokenSynced = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('NotificationService: Firebase failed to initialize: $e');
      return;
    }

    if (Platform.isAndroid) {
      await Permission.notification.request();
    } else {
      await _fcm.requestPermission(alert: true, sound: true, badge: true);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            final Map<String, dynamic> data = jsonDecode(payload);
            _handleNotificationPayload(data);
          } catch (e) {
            debugPrint(
              'NotificationService: Error parsing local notification payload: $e',
            );
          }
        }
      },
    );

    // 1. Foreground Message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
    });

    // 2. Background/Clicked Message listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationPayload(message.data);
    });

    // 3. Terminated / Initial Launch Message listener
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationPayload(initialMessage.data);
    }

    _fcm.onTokenRefresh.listen((token) {
      syncTokenToSupabase(token);
    });

    _initialized = true;
  }

  Future<void> syncTokenToSupabase([String? explicitToken]) async {
    if (_tokenSynced && explicitToken == null) return;

    try {
      final token = explicitToken ?? await _fcm.getToken();
      if (token == null) return;

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      try {
        await Supabase.instance.client.rpc(
          'upsert_user_fcm_token',
          params: {'p_token': token, 'p_device_type': _deviceType},
        );
        _tokenSynced = true;
        debugPrint('NotificationService: Token synced via RPC successfully.');
        return;
      } catch (rpcError) {
        debugPrint(
          'NotificationService: RPC token sync failed, falling back to direct ops: $rpcError',
        );
      }

      // Fallback: delete existing token for user before upsert
      try {
        await Supabase.instance.client
            .from('user_fcm_tokens')
            .delete()
            .eq('user_id', userId);
      } catch (e) {
        debugPrint(
          'NotificationService: deleting the stale FCM token before upsert failed: $e',
        );
      }

      await Supabase.instance.client.from('user_fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'device_type': _deviceType,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');

      _tokenSynced = true;
      debugPrint('NotificationService: Token synced successfully.');
    } catch (e) {
      debugPrint('NotificationService: Failed to sync token to Supabase: $e');
    }
  }

  /// Remove the current device's FCM token from Supabase on logout (Audit 12.1)
  Future<void> clearToken() async {
    try {
      final token = await _fcm.getToken();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (token != null && userId != null) {
        await Supabase.instance.client
            .from('user_fcm_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('token', token);
      }
      _tokenSynced = false;
    } catch (e) {
      debugPrint('NotificationService: Failed to clear token: $e');
    }
  }

  Future<void> sendPartnerNotification({
    required String title,
    required String body,
    required String feature,
    String? itemId,
    Map<String, String>? extraData,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await client.functions.invoke(
        'send-push-notification',
        body: {
          'sender_id': userId,
          'title': title,
          'body': body,
          'feature': feature,
          'item_id': itemId,
          'data': extraData ?? {},
        },
      );
    } catch (e) {
      debugPrint('NotificationService: Failed to send push notification: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null && !kIsWeb) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'Used for important notifications from your partner.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Resolves a notification payload to a route and hands it to the router
  /// -- this service never imports a screen or constructs a
  /// `MaterialPageRoute` (architecture-rules.md, Rule 15; ADR-007). It also
  /// no longer duplicates the "is the user ready" check the old
  /// `navigatorKey`-based version had here: `appRouter`'s single `redirect`
  /// (see `app_router.dart`) already forces any requested route to the
  /// correct onboarding screen when the session isn't `ready`, including the
  /// case this service previously handled by silently dropping the payload
  /// -- a real, previously-unaddressed gap ADR-007 calls out explicitly (a
  /// deep link arriving mid-hydration is now deferred and replayed, not
  /// lost).
  ///
  /// On a *cold start* (the app was terminated and a notification tap
  /// launched it), [init] resolves `getInitialMessage()` before `runApp` has
  /// run, so there is no router yet -- reading [appRouter] would throw and
  /// take the rest of app initialization down with it. That case hands the
  /// location to [queueDeepLink] instead, which replays it through the very
  /// same pending-deep-link path once hydration finishes.
  /// Test-only seam onto [_handleNotificationPayload]: the real entry points
  /// are all Firebase Messaging streams, which need a platform channel a
  /// plain `flutter test` does not have.
  @visibleForTesting
  void handleNotificationPayloadForTest(Map<String, dynamic> data) =>
      _handleNotificationPayload(data);

  void _handleNotificationPayload(Map<String, dynamic> data) {
    final target = _targetForPayload(data);
    if (target == null) return;

    if (!appRouterIsReady) {
      queueDeepLink(target.location);
      return;
    }
    if (target.replace) {
      appRouter.go(target.location);
    } else {
      appRouter.push(target.location);
    }
  }

  /// The payload -> route mapping, kept pure so [_handleNotificationPayload]
  /// can decide between navigating now and queueing for replay.
  ///
  /// `replace` distinguishes the one target that is a *tab of the home shell*
  /// rather than a screen pushed on top of it -- pushing that would stack a
  /// second home over the first.
  ({String location, bool replace})? _targetForPayload(
    Map<String, dynamic> data,
  ) {
    final feature = data['feature'] as String?;
    final itemId = data['item_id'] as String?;
    if (feature == null) return null;

    return switch (feature) {
      'chat' => (location: Routes.chat, replace: false),
      'bucket_list' => (location: Routes.bucketList, replace: false),
      'love_meter' ||
      'daily_prompt' => (location: Routes.loveMeter, replace: false),
      'doodle_notes' => (location: Routes.notes, replace: false),
      'timeline' || 'memories' =>
        itemId != null
            ? (location: Routes.memory(itemId), replace: false)
            : (location: Routes.homeTab(1), replace: true),
      'time_capsule' => (location: Routes.timeCapsule, replace: false),
      'calendar' => (location: Routes.calendar, replace: false),
      'vault' => (location: Routes.vault, replace: false),
      'topic_cards' => (location: Routes.topicCards, replace: false),
      'relationship' => (location: Routes.license, replace: false),
      'gifts' => (location: Routes.gifts, replace: false),
      _ => null,
    };
  }
}
