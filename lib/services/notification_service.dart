import 'dart:convert';
import 'dart:io';
import 'package:days_together/navigator_key.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/screens/love_story_screen.dart';
import 'package:days_together/screens/studio/time_capsule_screen.dart';
import 'package:days_together/screens/together/bucket_list_screen.dart';
import 'package:days_together/screens/together/calendar_screen.dart';
import 'package:days_together/screens/together/gift_reminders_screen.dart';
import 'package:days_together/screens/together/love_chat_screen.dart';
import 'package:days_together/screens/together/love_meter_screen.dart';
import 'package:days_together/screens/together/noteit_screen.dart';
import 'package:days_together/screens/together/relationship_license_screen.dart';
import 'package:days_together/screens/together/topic_cards_screen.dart';
import 'package:days_together/screens/together/vault_screen.dart';
import 'package:days_together/widgets/timeline_item.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
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

  void _handleNotificationPayload(Map<String, dynamic> data) {
    final feature = data['feature'] as String?;
    final itemId = data['item_id'] as String?;
    if (feature == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Check if the user is logged in and has completed onboarding before allowing sub-screen navigation
    final rp = context.read<RelationshipProvider>();
    if (rp.userId == null || !rp.isOnboardingComplete) {
      debugPrint('NotificationService: Bypassing payload routing because user is not authenticated or onboarding is incomplete.');
      return;
    }

    final state = navigatorKey.currentState;
    if (state == null) return;

    void navigateToTab(int index) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        final lss = LoveStoryScreen.of(context);
        if (lss != null) {
          lss.setIndex(index);
          state.popUntil((route) => route.isFirst);
          return;
        }
      }
      state.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoveStoryScreen(initialIndex: index)),
        (route) => false,
      );
    }

    switch (feature) {
      case 'chat':
        state.push(MaterialPageRoute(builder: (_) => const LoveChatScreen()));
        break;
      case 'bucket_list':
        state.push(MaterialPageRoute(builder: (_) => const BucketListScreen()));
        break;
      case 'love_meter':
      case 'daily_prompt':
        state.push(MaterialPageRoute(builder: (_) => const LoveMeterScreen()));
        break;
      case 'doodle_notes':
        state.push(MaterialPageRoute(builder: (_) => const NoteitScreen()));
        break;
      case 'timeline':
      case 'memories':
        if (itemId != null) {
          final context = navigatorKey.currentContext;
          if (context != null) {
            try {
              final provider = context.read<TimelineProvider>();
              final item = provider.timelineItems.firstWhere((i) => i.id == itemId);
              state.push(MaterialPageRoute(builder: (_) => MemoryDetailScreen(item: item)));
              return;
            } catch (_) {}
          }
        }
        navigateToTab(1);
        break;
      case 'time_capsule':
        state.push(MaterialPageRoute(builder: (_) => const TimeCapsuleScreen()));
        break;
      case 'calendar':
        state.push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
        break;
      case 'vault':
        state.push(MaterialPageRoute(builder: (_) => const VaultScreen()));
        break;
      case 'topic_cards':
        state.push(MaterialPageRoute(builder: (_) => const TopicCardsScreen()));
        break;
      case 'relationship':
        state.push(MaterialPageRoute(builder: (_) => const RelationshipLicenseScreen()));
        break;
      case 'gifts':
        state.push(MaterialPageRoute(builder: (_) => const GiftRemindersScreen()));
        break;
    }
  }
}
