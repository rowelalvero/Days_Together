# Design Specification: Push Notifications via Supabase & Firebase Cloud Messaging (FCM)

**Date:** 2026-06-22
**Status:** Approved
**Topic:** Real-time push notifications for couple sync alerts

---

## 1. Goal & Objectives
Enable real-time push notifications on client devices (Android/iOS) when a partner performs an action in the app.
Key use cases:
- **Love Chat / Notes**: Notify the partner of a new message.
- **Mood Synced**: Notify the partner when a daily mood/question response is posted.
- **Timeline Memories**: Notify the partner when a shared memory is created or modified.

---

## 2. Database Schema (`user_fcm_tokens`)
We store registered FCM registration tokens for each user. A single user can have multiple device tokens.

### SQL Migration script
```sql
-- Create table for FCM tokens
CREATE TABLE public.user_fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  device_type TEXT, -- 'android' or 'ios'
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

-- Indexes for fast lookups
CREATE INDEX idx_user_fcm_tokens_user_id ON public.user_fcm_tokens(user_id);
```

---

## 3. Flutter Client Configuration & Code

### 3.1. Add Dependencies (`pubspec.yaml`)
```yaml
dependencies:
  firebase_core: ^2.27.0
  firebase_messaging: ^14.7.15
  flutter_local_notifications: ^18.0.1
```

### 3.2. Gradle Configurations (Kotlin DSL)
- **settings.gradle.kts**:
  ```kotlin
  plugins {
      id("com.google.gms.google-services") version "4.4.1" apply false
  }
  ```
- **app/build.gradle.kts**:
  ```kotlin
  plugins {
      id("com.google.gms.google-services")
  }
  ```

### 3.3. Notification Service (`lib/services/notification_service.dart`)
Create a singleton `NotificationService` class to request permissions, get tokens, refresh tokens, and handle message listeners.

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

    // 1. Initialize Firebase Core
    await Firebase.initializeApp();

    // 2. Request Permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Configure Local Notifications (Foreground presentations)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // 4. Foreground Message Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
    });

    // 5. Token Refresh Handler
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
    } catch (e) {
      debugPrint('NotificationService: Failed to sync token to Supabase: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification != null && android != null && !kIsWeb) {
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

---

## 4. Backend/Edge Function Setup
Deploy a Supabase Edge Function to route alerts to partner devices using FCM v1 HTTP API.

### `supabase/functions/send-push-notification/index.ts`
```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8"

// Parse the service account key from env variables (stored inside Supabase dashboard secrets)
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  try {
    const { sender_id, title, body, data } = await req.json();

    if (!sender_id || !title || !body) {
      return new Response(JSON.stringify({ error: "Missing parameters" }), { status: 400 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Get the sender's couple_id
    const { data: sender, error: senderErr } = await supabase
      .from('users')
      .select('couple_id')
      .eq('id', sender_id)
      .single();

    if (senderErr || !sender?.couple_id) {
      return new Response(JSON.stringify({ error: "Sender not found or not paired" }), { status: 404 });
    }

    // 2. Find the partner's id
    const { data: partner, error: partnerErr } = await supabase
      .from('users')
      .select('id')
      .eq('couple_id', sender.couple_id)
      .neq('id', sender_id)
      .single();

    if (partnerErr || !partner) {
      return new Response(JSON.stringify({ error: "Partner not found" }), { status: 404 });
    }

    // 3. Get partner device tokens
    const { data: tokenRows, error: tokenErr } = await supabase
      .from('user_fcm_tokens')
      .select('token')
      .eq('user_id', partner.id);

    if (tokenErr || !tokenRows || tokenRows.length === 0) {
      return new Response(JSON.stringify({ message: "No registered tokens found for partner" }), { status: 200 });
    }

    const tokens = tokenRows.map((r) => r.token);

    // 4. Generate FCM OAuth2 Access Token using Deno and Firebase credentials
    const credentials = JSON.parse(FIREBASE_SERVICE_ACCOUNT!);
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

    return new Response(JSON.stringify({ success: true, results }), { status: 200 });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});

// Helper to sign JWT and fetch google OAuth2 access token
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

// Signs and encodes JWT payload with Deno Crypto APIs
async function generateJWT(header: any, claim: any, privateKeyPem: string): Promise<string> {
  const textEncoder = new TextEncoder();
  const base64UrlEncode = (str: string) => btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaim = base64UrlEncode(JSON.stringify(claim));
  const signingInput = `${encodedHeader}.${encodedClaim}`;

  // Parse RSA Private Key PEM
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

---

## 5. Verification & Testing Plan
1. **Database Setup**: Execute the table-creation script in Supabase SQL editor.
2. **App Compilation**: Verify the app builds successfully on Android after modifying gradle configuration.
3. **Token sync**: Log in, trigger onboarding, and verify that a token record is inserted into `user_fcm_tokens` under the active user's UUID.
4. **Trigger notification**: Call the Supabase Edge Function with a test JSON payload using `curl` or Postman, verifying the notification is delivered and displayed correctly on both background and foreground states.
