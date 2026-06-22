# Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real-time push notifications to the app to notify the partner of new Love Chat messages, mood sync events, and timeline memories.

**Architecture:** Sync device FCM registration tokens from the Flutter client to a new `user_fcm_tokens` table in Supabase. Trigger a Supabase Edge Function to authenticate with Google APIs using a Service Account JSON secret and deliver push notifications via the FCM v1 HTTP API.

**Tech Stack:** Flutter, Firebase Messaging, Firebase Core, Supabase, Deno, TypeScript.

## Global Constraints
- Target platform: Android / iOS (using Google Services dependencies and plugins).
- Firebase dependencies version floors: `firebase_core: ^2.27.0`, `firebase_messaging: ^14.7.15`.
- Database schemas must use public schemas and Row Level Security (RLS) policies.
- Edge functions must be compatible with Deno runtime and connect to Supabase via standard JS/TS client.

---

### Task 1: Supabase Database Setup

**Files:**
- Create: `supabase/migrations/20260622_create_user_fcm_tokens.sql`

**Interfaces:**
- Consumes: None (creates new table)
- Produces: `public.user_fcm_tokens` database table with RLS policy and index.

- [ ] **Step 1: Create SQL migration script**
  Write the table creation and security policy script.
  Create file [20260622_create_user_fcm_tokens.sql](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/supabase/migrations/20260622_create_user_fcm_tokens.sql):
  ```sql
  -- Create table for FCM tokens
  CREATE TABLE public.user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    device_type TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- Enable Row Level Security
  ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

  -- RLS Policies
  CREATE POLICY "Users can insert their own FCM tokens"
    ON public.user_fcm_tokens FOR INSERT
    WITH CHECK (auth.uid() = user_id);

  CREATE POLICY "Users can view their own FCM tokens"
    ON public.user_fcm_tokens FOR SELECT
    USING (auth.uid() = user_id);

  CREATE POLICY "Users can update their own FCM tokens"
    ON public.user_fcm_tokens FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

  CREATE POLICY "Users can delete their own FCM tokens"
    ON public.user_fcm_tokens FOR DELETE
    USING (auth.uid() = user_id);

  -- Index for user_id query performance
  CREATE INDEX idx_user_fcm_tokens_user_id ON public.user_fcm_tokens(user_id);
  ```

- [ ] **Step 2: Commit**
  Run:
  ```bash
  git add supabase/migrations/20260622_create_user_fcm_tokens.sql
  git commit -m "db: create user_fcm_tokens table with RLS"
  ```

---

### Task 2: Gradle Configuration & Flutter Dependencies

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/settings.gradle.kts`
- Modify: `android/app/build.gradle.kts`

**Interfaces:**
- Consumes: None (updates project dependency configuration)
- Produces: Updated Android gradle setup supporting Google Services; Firebase client dependencies on path.

- [ ] **Step 1: Update dependencies in `pubspec.yaml`**
  Modify [pubspec.yaml](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/pubspec.yaml):
  Add `firebase_core` and `firebase_messaging` under dependencies:
  ```yaml
    google_fonts: ^6.2.1
    flutter_local_notifications: ^18.0.1
    firebase_core: ^2.27.0
    firebase_messaging: ^14.7.15
    qr_flutter: ^4.1.0
  ```

- [ ] **Step 2: Update `android/settings.gradle.kts`**
  Modify [settings.gradle.kts](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/android/settings.gradle.kts):
  Add `id("com.google.gms.google-services") version "4.4.1" apply false` inside the plugins block:
  ```kotlin
  plugins {
      id("dev.flutter.flutter-plugin-loader") version "1.0.0"
      id("com.android.application") version "8.11.1" apply false
      id("org.jetbrains.kotlin.android") version "2.2.20" apply false
      id("com.google.gms.google-services") version "4.4.1" apply false
  }
  ```

- [ ] **Step 3: Update `android/app/build.gradle.kts`**
  Modify [app/build.gradle.kts](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/android/app/build.gradle.kts):
  Add `id("com.google.gms.google-services")` to plugins block:
  ```kotlin
  plugins {
      id("com.android.application")
      id("kotlin-android")
      id("dev.flutter.flutter-gradle-plugin")
      id("com.google.gms.google-services")
  }
  ```

- [ ] **Step 4: Fetch dependencies and run build**
  Run:
  ```bash
  flutter pub get
  ```
  Expected output: Process finishes with code 0.

- [ ] **Step 5: Commit**
  Run:
  ```bash
  git add pubspec.yaml android/settings.gradle.kts android/app/build.gradle.kts
  git commit -m "build: add firebase dependencies and google-services gradle configurations"
  ```

---

### Task 3: Notification Service Implementation

**Files:**
- Create: `lib/services/notification_service.dart`

**Interfaces:**
- Consumes: `firebase_messaging` and `flutter_local_notifications`
- Produces: `NotificationService` class singleton with `init()` and `syncTokenToSupabase([String? explicitToken])` methods.

- [ ] **Step 1: Create notification service file**
  Create [notification_service.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/services/notification_service.dart):
  ```dart
  import 'dart:io';
  import 'package:firebase_core/firebase_core.dart';
  import 'package:firebase_messaging/firebase_messaging.dart';
  import 'package:flutter/foundation.dart';
  import 'package:flutter_local_notifications/flutter_local_notifications.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';

  class NotificationService {
    static final NotificationService _instance = NotificationService._internal();
    factory NotificationService() => _instance;
    NotificationService._internal();

    final FirebaseMessaging _fcm = FirebaseMessaging.instance;
    final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
    bool _initialized = false;

    Future<void> init() async {
      if (_initialized) return;

      try {
        await Firebase.initializeApp();
      } catch (e) {
        debugPrint('NotificationService: Firebase failed to initialize: $e');
        return;
      }

      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _localNotifications.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
      });

      _fcm.onTokenRefresh.listen((token) {
        syncTokenToSupabase(token);
      });

      _initialized = true;
    }

    Future<void> syncTokenToSupabase([String? explicitToken]) async {
      try {
        final token = explicitToken ?? await _fcm.getToken();
        if (token == null) return;

        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;

        await Supabase.instance.client.from('user_fcm_tokens').upsert({
          'user_id': userId,
          'token': token,
          'device_type': Platform.isIOS ? 'ios' : 'android',
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('NotificationService: Token synced successfully.');
      } catch (e) {
        debugPrint('NotificationService: Failed to sync token to Supabase: $e');
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
        );
      }
    }
  }
  ```

- [ ] **Step 2: Commit**
  Run:
  ```bash
  git add lib/services/notification_service.dart
  git commit -m "feat: implement NotificationService singleton"
  ```

---

### Task 4: Integration in Main & Authentication Lifecycle

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/providers/relationship_provider.dart`

**Interfaces:**
- Consumes: `NotificationService`
- Produces: Initialized notification handler on app launch; automatic token sync on auth status transitions.

- [ ] **Step 1: Initialize NotificationService in `lib/main.dart`**
  Modify [main.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/main.dart):
  Import `notification_service.dart` and call `init()` at main launch.
  Around line 22-33:
  ```dart
  import 'package:days_together/services/notification_service.dart';
  // ...
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await dotenv.load(fileName: ".env");
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? '',
        publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      );
      // Initialize Push Notification Service
      await NotificationService().init();
    } catch (e) {
      debugPrint('Supabase failed to initialize: $e');
    }
  ```

- [ ] **Step 2: Hook token sync in `RelationshipProvider`**
  Modify [relationship_provider.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/providers/relationship_provider.dart):
  Trigger token synchronization when the user successfully signs in and a couple session starts.
  Add import:
  ```dart
  import 'package:days_together/services/notification_service.dart';
  ```
  Inside the `_userSub` listener, around line 248, after inserting/loading userData:
  ```dart
                  final userData = dataList.first;
                  _coupleId = userData['couple_id'] as String?;
                  _partnerId = userData['partner_id'] as String?;
                  
                  // Trigger token synchronization when authenticated
                  NotificationService().syncTokenToSupabase();
  ```

- [ ] **Step 3: Commit**
  Run:
  ```bash
  git add lib/main.dart lib/providers/relationship_provider.dart
  git commit -m "feat: initialize notification service and sync FCM token on login"
  ```

---

### Task 5: Supabase Edge Function Deployment

**Files:**
- Create: `supabase/functions/send-push-notification/index.ts`

**Interfaces:**
- Consumes: Google Firebase Service Account Environment Variable (`FIREBASE_SERVICE_ACCOUNT_JSON`).
- Produces: Edge function API endpoint `/functions/v1/send-push-notification` accepting JSON payload.

- [ ] **Step 1: Write Edge Function TypeScript Code**
  Create file [index.ts](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/supabase/functions/send-push-notification/index.ts):
  ```typescript
  import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
  import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8"

  const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
  const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  serve(async (req) => {
    // Enable CORS
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } });
    }

    try {
      const { sender_id, title, body, data } = await req.json();

      if (!sender_id || !title || !body) {
        return new Response(JSON.stringify({ error: "Missing parameters" }), {
          status: 400,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
        });
      }

      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

      // 1. Get the sender's couple_id
      const { data: sender, error: senderErr } = await supabase
        .from('users')
        .select('couple_id')
        .eq('id', sender_id)
        .single();

      if (senderErr || !sender?.couple_id) {
        return new Response(JSON.stringify({ error: "Sender not found or not paired" }), {
          status: 404,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
        });
      }

      // 2. Find the partner's id
      const { data: partner, error: partnerErr } = await supabase
        .from('users')
        .select('id')
        .eq('couple_id', sender.couple_id)
        .neq('id', sender_id)
        .single();

      if (partnerErr || !partner) {
        return new Response(JSON.stringify({ error: "Partner not found" }), {
          status: 404,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
        });
      }

      // 3. Get partner device tokens
      const { data: tokenRows, error: tokenErr } = await supabase
        .from('user_fcm_tokens')
        .select('token')
        .eq('user_id', partner.id);

      if (tokenErr || !tokenRows || tokenRows.length === 0) {
        return new Response(JSON.stringify({ message: "No registered tokens found for partner" }), {
          status: 200,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
        });
      }

      const tokens = tokenRows.map((r) => r.token);

      // 4. Generate FCM OAuth2 Access Token using Deno and Firebase credentials
      if (!FIREBASE_SERVICE_ACCOUNT) {
        throw new Error("Missing FIREBASE_SERVICE_ACCOUNT_JSON secret in Supabase dashboard");
      }
      const credentials = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
      const accessToken = await getAccessToken(credentials);

      // 5. Send FCM alerts
      const results = [];
      for (const token of tokens) {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${credentials.project_id}/messages:send`,
          {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token: token,
                notification: { title, body },
                data: data || {},
              },
            }),
          }
        );
        results.push({ token, status: response.status });
      }

      return new Response(JSON.stringify({ success: true, results }), {
        status: 200,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    } catch (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    }
  });

  async function getAccessToken(credentials: any): Promise<string> {
    const header = { alg: "RS256", typ: "JWT" };
    const now = Math.floor(Date.now() / 1000);
    const claim = {
      iss: credentials.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    };

    const jwt = await generateJWT(header, claim, credentials.private_key);

    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
    });
    const data = await res.json();
    return data.access_token;
  }

  async function generateJWT(header: any, claim: any, privateKeyPem: string): Promise<string> {
    const textEncoder = new TextEncoder();
    const base64UrlEncode = (str: string) => btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

    const encodedHeader = base64UrlEncode(JSON.stringify(header));
    const encodedClaim = base64UrlEncode(JSON.stringify(claim));
    const signingInput = `${encodedHeader}.${encodedClaim}`;

    const pemHeader = "-----BEGIN PRIVATE KEY-----";
    const pemFooter = "-----END PRIVATE KEY-----";
    const pemContents = privateKeyPem
      .substring(privateKeyPem.indexOf(pemHeader) + pemHeader.length, privateKeyPem.indexOf(pemFooter))
      .replace(/\s/g, "");
    const binaryDerString = atob(pemContents);
    const binaryDer = new Uint8Array(binaryDerString.length);
    for (let i = 0; i < binaryDerString.length; i++) {
      binaryDer[i] = binaryDerString.charCodeAt(i);
    }

    const cryptoKey = await crypto.subtle.importKey(
      "pkcs8",
      binaryDer.buffer,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"]
    );

    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      cryptoKey,
      textEncoder.encode(signingInput)
    );

    const encodedSignature = base64UrlEncode(String.fromCharCode(...new Uint8Array(signature)));
    return `${signingInput}.${encodedSignature}`;
  }
  ```

- [ ] **Step 2: Commit**
  Run:
  ```bash
  git add supabase/functions/send-push-notification/index.ts
  git commit -m "feat: create Supabase Edge Function to route FCM notifications"
  ```

---

### Task 6: Provider Integrations (Love Chat, Mood, & Memories)

**Files:**
- Modify: `lib/providers/love_chat_provider.dart`
- Modify: `lib/providers/timeline_provider.dart`
- Modify: `lib/providers/daily_mood_provider.dart`

**Interfaces:**
- Consumes: Supabase Edge Functions client invoke API.
- Produces: Triggered Edge Function invocation when chat messages, timeline items, or moods are written.

- [ ] **Step 1: Trigger notification on Love Chat / Note additions**
  Modify [love_chat_provider.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/providers/love_chat_provider.dart):
  After successfully adding/saving a chat message, call the Edge Function.
  In `sendMessage(...)`, after writing the message:
  ```dart
        // Trigger push notification to partner
        try {
          await Supabase.instance.client.functions.invoke(
            'send-push-notification',
            body: {
              'sender_id': _userId,
              'title': 'New Love Note 💖',
              'body': text.length > 50 ? '${text.substring(0, 47)}...' : text,
            },
          );
        } catch (e) {
          debugPrint('Failed to send push notification: $e');
        }
  ```

- [ ] **Step 2: Trigger notification on Timeline Memory additions**
  Modify [timeline_provider.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/providers/timeline_provider.dart):
  Inside `addMemory(...)` or `saveMemory(...)` (after Supabase inserts have completed successfully):
  ```dart
        // Trigger push notification to partner
        try {
          await Supabase.instance.client.functions.invoke(
            'send-push-notification',
            body: {
              'sender_id': _userId,
              'title': 'New Memory Shared 📸',
              'body': 'A new memory was added to your timeline: $title',
            },
          );
        } catch (e) {
          debugPrint('Failed to send memory push notification: $e');
        }
  ```

- [ ] **Step 3: Trigger notification on Daily Mood additions**
  Modify [daily_mood_provider.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/providers/daily_mood_provider.dart):
  Inside `saveMood(...)` or `submitAnswer(...)` after saving the answer:
  ```dart
        // Trigger push notification to partner
        try {
          await Supabase.instance.client.functions.invoke(
            'send-push-notification',
            body: {
              'sender_id': _userId,
              'title': 'Mood Sync Alert 💖',
              'body': 'Your partner updated their daily mood and sync question response!',
            },
          );
        } catch (e) {
          debugPrint('Failed to send mood sync push notification: $e');
        }
  ```

- [ ] **Step 4: Commit**
  Run:
  ```bash
  git add lib/providers/love_chat_provider.dart lib/providers/timeline_provider.dart lib/providers/daily_mood_provider.dart
  git commit -m "feat: trigger FCM notification calls in providers on content creation"
  ```
