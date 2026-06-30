# Architecture and UI/UX Refactoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the codebase to introduce a modular service layer, centralize real-time synchronization, and improve UX form keyboard navigation without modifying any features.

**Architecture:** Split data access in `RelationshipProvider` into distinct services (`AuthService`, `CoupleService`, `ProfileService`) while preserving the existing ChangeNotifier state getters/setters for 100% backward compatibility. Centralize Supabase real-time subscriptions in a reusable `SupabaseSyncService`. Introduce `textInputAction` focus shifts across text input forms.

**Tech Stack:** Flutter, Supabase Client, ChangeNotifier / Provider state management.

## Global Constraints
- Avoid breaking changes to existing getters/setters/state in `RelationshipProvider`.
- Do not modify existing UI screen styles or remove existing logic.
- Avoid duplicate stream listen subscriptions and centralize error handling.

---

### Task 1: Create Centralized SupabaseSyncService

**Files:**
- Create: `lib/services/supabase_sync_service.dart`

**Interfaces:**
- Consumes: Supabase Flutter Client
- Produces: `SupabaseSyncService.subscribeToCoupleData`

- [ ] **Step 1: Write the service class**

Create `lib/services/supabase_sync_service.dart`:
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSyncService {
  SupabaseSyncService._();
  static final SupabaseSyncService instance = SupabaseSyncService._();

  StreamSubscription<List<Map<String, dynamic>>> subscribeToCoupleData({
    required String tableName,
    required String coupleId,
    required void Function(List<Map<String, dynamic>> data) onData,
    required void Function(Object error) onError,
    List<String> primaryKey = const ['id'],
  }) {
    try {
      return Supabase.instance.client
          .from(tableName)
          .stream(primaryKey: primaryKey)
          .eq('couple_id', coupleId)
          .listen(
            onData,
            onError: (err) {
              debugPrint('SupabaseSyncService: stream error on $tableName: $err');
              onError(err);
            },
          );
    } catch (e) {
      debugPrint('SupabaseSyncService: failed to subscribe to $tableName: $e');
      onError(e);
      return const Stream<List<Map<String, dynamic>>>.empty().listen(onData);
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/supabase_sync_service.dart
git commit -m "refactor: add SupabaseSyncService for database streams"
```

---

### Task 2: Implement AuthService, CoupleService, and ProfileService

**Files:**
- Create: `lib/services/auth_service.dart`
- Create: `lib/services/couple_service.dart`
- Create: `lib/services/profile_service.dart`

**Interfaces:**
- Consumes: Supabase Flutter SDK APIs
- Produces: `AuthService`, `CoupleService`, and `ProfileService` singleton instances.

- [ ] **Step 1: Create AuthService**

Create `lib/services/auth_service.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<AuthResponse> signUpWithEmail(String email, String password) {
    return Supabase.instance.client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signInWithEmail(String email, String password) {
    return Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signInWithIdToken({required String idToken, required String accessToken}) {
    return Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() {
    return Supabase.instance.client.auth.signOut();
  }

  Future<void> deleteUserAccount() async {
    await Supabase.instance.client.rpc('delete_current_user');
  }
}
```

- [ ] **Step 2: Create CoupleService**

Create `lib/services/couple_service.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class CoupleService {
  CoupleService._();
  static final CoupleService instance = CoupleService._();

  Future<Map<String, dynamic>> joinWithCode(String code) async {
    final response = await Supabase.instance.client.rpc(
      'join_couple_with_code',
      params: {'code': code},
    );
    return Map<String, dynamic>.from(response);
  }

  Future<void> unlinkPartner({required String coupleId, required String userId}) async {
    await Supabase.instance.client
        .from('couples')
        .update({'partner_id': null})
        .eq('id', coupleId);
    await Supabase.instance.client
        .from('users')
        .update({'couple_id': null, 'partner_id': null})
        .eq('id', userId);
  }
}
```

- [ ] **Step 3: Create ProfileService**

Create `lib/services/profile_service.dart`:
```dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  Future<void> updateUserDetails(String userId, Map<String, dynamic> data) async {
    await Supabase.instance.client
        .from('users')
        .update(data)
        .eq('id', userId);
  }

  Future<void> updateCoupleDetails(String coupleId, Map<String, dynamic> data) async {
    await Supabase.instance.client
        .from('couples')
        .update(data)
        .eq('id', coupleId);
  }

  Future<void> updateLicenseDetails(String coupleId, Map<String, dynamic> data) async {
    await Supabase.instance.client
        .from('relationship_licenses')
        .update(data)
        .eq('couple_id', coupleId);
  }

  Future<Map<String, dynamic>?> fetchLicenseDetails(String coupleId) async {
    final list = await Supabase.instance.client
        .from('relationship_licenses')
        .select()
        .eq('couple_id', coupleId);
    return list.isNotEmpty ? list.first : null;
  }

  Future<String> uploadAvatar({
    required String bucketName,
    required String filePath,
    required String storagePath,
  }) async {
    final file = File(filePath);
    await Supabase.instance.client.storage
        .from(bucketName)
        .upload(storagePath, file, fileOptions: const FileOptions(upsert: true));

    final publicUrl = Supabase.instance.client.storage
        .from(bucketName)
        .getPublicUrl(storagePath);
    return publicUrl;
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/services/auth_service.dart lib/services/couple_service.dart lib/services/profile_service.dart
git commit -m "refactor: add AuthService, CoupleService, and ProfileService"
```

---

### Task 3: Refactor RelationshipProvider to Delegate to Services

**Files:**
- Modify: `lib/providers/relationship_provider.dart`

**Interfaces:**
- Consumes: `AuthService`, `CoupleService`, `ProfileService`
- Produces: Updated state getters and setters, maintaining identical external API signatures.

- [ ] **Step 1: Replace authentication logic**

Replace the implementation of `signUpWithEmail`, `signInWithEmail`, `signInWithGoogle`, `logout`, and `deleteAccount` with service delegations inside `lib/providers/relationship_provider.dart`:
```dart
  Future<void> signUpWithEmail(String email, String password) async {
    await AuthService.instance.signUpWithEmail(email, password);
  }

  Future<void> signInWithEmail(String email, String password) async {
    await AuthService.instance.signInWithEmail(email, password);
  }

  Future<void> deleteAccount() async {
    await AuthService.instance.deleteUserAccount();
    await logout();
  }
```

- [ ] **Step 2: Replace pairing logic**

Replace `joinWithCode` and `unlinkPartner`:
```dart
  Future<bool> joinWithCode(String code) async {
    if (_isJoining) return false;
    _isJoining = true;
    notifyListeners();

    try {
      final result = await CoupleService.instance.joinWithCode(code);
      final bool success = result['success'] as bool? ?? false;
      if (!success) {
        throw Exception(result['error'] as String? ?? 'Pairing failed');
      }

      final joinedCoupleId = result['couple_id'] as String;
      final partnerId = result['partner_id'] as String;

      _coupleId = joinedCoupleId;
      _partnerId = partnerId;
      _isPaired = true;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('couple_id', joinedCoupleId);
      await prefs.setString('partner_id', partnerId);
      await prefs.setBool('is_paired', true);

      // fetch couple and details
      final coupleData = await Supabase.instance.client
          .from('couples')
          .select()
          .eq('id', joinedCoupleId)
          .single();

      final startStr = coupleData['start_date'] as String?;
      if (startStr != null) {
        _startDate = DateTime.parse(startStr);
        await prefs.setString('relationship_start_date', startStr);
      }
      _isJoining = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isJoining = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> unlinkPartner() async {
    if (_coupleId == null || _userId == null || _isUnlinking) return;
    _isUnlinking = true;
    notifyListeners();

    try {
      await CoupleService.instance.unlinkPartner(coupleId: _coupleId!, userId: _userId!);
      
      _coupleId = null;
      _partnerId = null;
      _isPaired = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('couple_id');
      await prefs.remove('partner_id');
      await prefs.setBool('is_paired', false);
      
      _isUnlinking = false;
      notifyListeners();
    } catch (e) {
      _isUnlinking = false;
      notifyListeners();
      rethrow;
    }
  }
```

- [ ] **Step 3: Replace profile editing logic**

Delegate update methods to `ProfileService`:
- `setYourName`, `setNames`, `setGenders`, `setPhoneNumbers`, `setBirthdates`, `setAddresses`, `setNationalities`, `setWeightsAndHeights`, `setBloodAndEyes`, `setConditionsAndDateIssued`, `setYourSignature`, `setPartnerSignature`, `setAvatars`.

Example for `setYourName`:
```dart
  Future<void> setYourName(String name) async {
    _yourName = name;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('your_name', name);

    if (_userId != null) {
      await ProfileService.instance.updateUserDetails(_userId!, {'name': name});
    }
  }
```

Example for `setAvatars`:
```dart
  Future<void> setAvatars({String? yourPath, String? partnerPath}) async {
    final prefs = await SharedPreferences.getInstance();
    if (yourPath != null) {
      _yourAvatarPath = yourPath;
      await prefs.setString('your_avatar_path', yourPath);
      notifyListeners();

      if (_userId != null) {
        final storagePath = 'avatars/$_userId.jpg';
        final publicUrl = await ProfileService.instance.uploadAvatar(
          bucketName: 'avatars',
          filePath: yourPath,
          storagePath: storagePath,
        );
        _yourAvatarPath = publicUrl;
        await prefs.setString('your_avatar_path', publicUrl);
        await ProfileService.instance.updateUserDetails(_userId!, {'avatar_url': publicUrl});
        notifyListeners();
      }
    }
    // Repeat for partnerPath...
  }
```

- [ ] **Step 4: Commit**

```bash
git add lib/providers/relationship_provider.dart
git commit -m "refactor: delegate authentication, pairing, and profile update logic to services"
```

---

### Task 4: Integrate SupabaseSyncService into Database Providers

**Files:**
- Modify: `lib/providers/time_capsule_provider.dart`
- Modify: `lib/providers/bucket_list_provider.dart`
- Modify: `lib/providers/calendar_provider.dart`
- Modify: `lib/providers/daily_mood_provider.dart`
- Modify: `lib/providers/gift_reminder_provider.dart`
- Modify: `lib/providers/love_chat_provider.dart`
- Modify: `lib/providers/noteit_provider.dart`
- Modify: `lib/providers/timeline_provider.dart`
- Modify: `lib/providers/topic_cards_provider.dart`
- Modify: `lib/providers/vault_provider.dart`

**Interfaces:**
- Consumes: `SupabaseSyncService`
- Produces: Simplified subscription logic inside each database provider.

- [ ] **Step 1: Update TimeCapsuleProvider**

Update `_initSupabaseSync()` inside `lib/providers/time_capsule_provider.dart`:
```dart
    _syncSub = SupabaseSyncService.instance.subscribeToCoupleData(
      tableName: 'time_capsules',
      coupleId: _coupleId!,
      onData: (dataList) {
        _capsules = dataList.map((data) {
          return TimeCapsule(
            id: data['id'] as String,
            message: data['message'] ?? '',
            openDate: data['open_date'] != null ? DateTime.parse(data['open_date'] as String) : DateTime.now(),
            isOpened: data['is_opened'] ?? false,
            createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'] as String) : DateTime.now(),
          );
        }).toList();

        _capsules.sort((a, b) => a.openDate.compareTo(b.openDate));
        _isLoading = false;
        if (!_disposed) notifyListeners();
        _persistLocalOnly();
      },
      onError: (err) {
        debugPrint('TimeCapsuleProvider: Supabase sync error: $err');
        _loadCapsules();
      },
    );
```

- [ ] **Step 2: Update BucketListProvider**

Update `_initSupabaseSync()` inside `lib/providers/bucket_list_provider.dart`:
```dart
    _syncSub = SupabaseSyncService.instance.subscribeToCoupleData(
      tableName: 'bucket_list',
      coupleId: _coupleId!,
      onData: (dataList) {
        _items = dataList.map((data) {
          return BucketListItem(
            id: data['id'] as String,
            title: data['title'] ?? '',
            isCompleted: data['is_completed'] ?? false,
            createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'] as String) : DateTime.now(),
          );
        }).toList();

        _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
        if (!_disposed) notifyListeners();
        _persistLocalOnly();
      },
      onError: (err) {
        debugPrint('BucketListProvider: Supabase sync error: $err');
        _loadItems();
      },
    );
```

- [ ] **Step 3: Update other database providers**

Follow the same pattern to refactor `_initSupabaseSync()` for the remaining providers:
- `CalendarProvider`
- `DailyMoodProvider`
- `GiftReminderProvider`
- `LoveChatProvider`
- `NoteitProvider`
- `TimelineProvider`
- `TopicCardsProvider`
- `VaultProvider`

- [ ] **Step 4: Commit**

```bash
git add lib/providers/time_capsule_provider.dart lib/providers/bucket_list_provider.dart lib/providers/calendar_provider.dart lib/providers/daily_mood_provider.dart lib/providers/gift_reminder_provider.dart lib/providers/love_chat_provider.dart lib/providers/noteit_provider.dart lib/providers/timeline_provider.dart lib/providers/topic_cards_provider.dart lib/providers/vault_provider.dart
git commit -m "refactor: integrate SupabaseSyncService into database-driven providers"
```

---

### Task 5: Enhance UI Keyboard Navigation and Focus Management

**Files:**
- Modify: `lib/screens/onboarding/auth_screen.dart`
- Modify: `lib/screens/together/relationship_license_screen.dart`

**Interfaces:**
- Consumes: Material TextFields
- Produces: Polished focus-advancement behaviors on keyboards.

- [ ] **Step 1: Refactor AuthScreen**

In `lib/screens/onboarding/auth_screen.dart`, update the `TextFormField` fields to define the correct `textInputAction` values.
Email:
```dart
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: AppTypography.body(color: theme.textColor),
```
Password:
```dart
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: _isSignUp ? TextInputAction.next : TextInputAction.done,
                            style: AppTypography.body(color: theme.textColor),
```

- [ ] **Step 2: Refactor RelationshipLicenseScreen Forms**

In `lib/screens/together/relationship_license_screen.dart`, configure all `TextField` objects in `_buildCreationForm` and `_buildForm` to utilize sequential `textInputAction: TextInputAction.next` actions, ending with `TextInputAction.done` on the Phone/Mobile number field.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/auth_screen.dart lib/screens/together/relationship_license_screen.dart
git commit -m "ux: polish text input keyboard actions and focus transitions"
```

---

### Task 6: Validate and Verify Compilation

**Files:**
- None (verify workspace)

- [ ] **Step 1: Run static analysis**

Run: `flutter analyze`
Expected: 0 issues found

- [ ] **Step 2: Commit**

```bash
git status
```
