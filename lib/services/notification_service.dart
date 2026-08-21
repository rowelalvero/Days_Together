import 'dart:convert';
import 'dart:io';
import 'package:days_together/routing/app_router.dart';
import 'package:days_together/routing/routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
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
      await _fcm.requestPermission(
        alert: true,
        sound: true,
        badge: true,
      );
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
            debugPrint('NotificationService: Error parsing local notification payload: $e');
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
        await Supabase.instance.client.rpc('upsert_user_fcm_token', params: {
          'p_token': token,
          'p_device_type': Platform.isIOS ? 'ios' : 'android',
        });
        _tokenSynced = true;
        debugPrint('NotificationService: Token synced via RPC successfully.');
        return;
      } catch (rpcError) {
        debugPrint('NotificationService: RPC token sync failed, falling back to direct ops: $rpcError');
      }

      // Fallback: delete existing token for user before upsert
      try {
        await Supabase.instance.client
            .from('user_fcm_tokens')
            .delete()
            .eq('user_id', userId);
      } catch (_) {}

      await Supabase.instance.client.from('user_fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'device_type': Platform.isIOS ? 'ios' : 'android',
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
            channelDescription: 'Used for important notifications from your partner.',
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
  void _handleNotificationPayload(Map<String, dynamic> data) {
    final feature = data['feature'] as String?;
    final itemId = data['item_id'] as String?;
    if (feature == null) return;

    switch (feature) {
      case 'chat':
        appRouter.push(Routes.chat);
      case 'bucket_list':
        appRouter.push(Routes.bucketList);
      case 'love_meter':
      case 'daily_prompt':
        appRouter.push(Routes.loveMeter);
      case 'doodle_notes':
        appRouter.push(Routes.notes);
      case 'timeline':
      case 'memories':
        if (itemId != null) {
          appRouter.push(Routes.memory(itemId));
        } else {
          appRouter.go(Routes.homeTab(1));
        }
      case 'time_capsule':
        appRouter.push(Routes.timeCapsule);
      case 'calendar':
        appRouter.push(Routes.calendar);
      case 'vault':
        appRouter.push(Routes.vault);
      case 'topic_cards':
        appRouter.push(Routes.topicCards);
      case 'relationship':
        appRouter.push(Routes.license);
      case 'gifts':
        appRouter.push(Routes.gifts);
    }
  }
}
