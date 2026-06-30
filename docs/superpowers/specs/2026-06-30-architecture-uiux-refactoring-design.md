# Architecture and UI/UX Refactoring Design Spec

This document details the architectural refactoring plan for splitting `RelationshipProvider`, centralizing Supabase stream listening, and introducing polished keyboard navigation and form interactions across the Days Together application.

## 1. Architectural Improvements

### 1.1 Splitting RelationshipProvider
`RelationshipProvider` has grown to over 2,400 lines, taking on multiple distinct responsibilities:
- **Authentication**: Managing sign-in, sign-up, Google Sign-in, session status, account deletion, and logging out.
- **Pairing**: Creating code, joining with code, unlinking couples, and managing onboarding status.
- **Profile / Registry**: Modifying demographic fields (names, phone numbers, birthdates, addresses, weight, height, conditions), signing, and saving license parameters.
- **Avatar Storage**: Uploading, downloading, validating, and caching user and partner avatars.

#### Proposed Solution (Facade / Delegation Pattern)
To ensure **100% backward compatibility** and prevent breaking UI widgets or proxy provider registrations, we will:
1. Extract operations into distinct, testable service classes under `lib/services/`:
   - `AuthService`: Manages Supabase Auth calls, Google Sign-in, sign-up, session checking, and account deletion.
   - `CoupleService`: Manages pairing codes, unlinking partner, and setting pairing status.
   - `ProfileService`: Handles updates of user and partner fields, license metadata syncs, and uploading avatar files to Supabase Storage.
2. Refactor `RelationshipProvider` to hold the reactive UI state (getters/setters) and delegate database/API calls to these services, notifying listeners when state properties change.

### 1.2 Centralizing Supabase Stream Listeners
Currently, multiple providers (`TimeCapsuleProvider`, `BucketListProvider`, `CalendarProvider`, `DailyMoodProvider`, `GiftReminderProvider`, `LoveChatProvider`, `NoteitProvider`, `TimelineProvider`, `TopicCardsProvider`, `VaultProvider`) duplicate the boilerplates for initializing, querying, and catching errors on Supabase real-time streams.

#### Proposed Solution
1. Create a `SupabaseSyncService` in `lib/services/supabase_sync_service.dart`.
2. Expose a unified subscription function that configures the stream listener, handles error formatting, and logs sync status.
3. Update all providers to delegate stream creation to `SupabaseSyncService.instance.subscribeToCoupleData(...)`.

---

## 2. UI/UX Form Polish

### 2.1 Soft Keyboard Navigation
The application contains several screens with sequential text inputs (e.g. `AuthScreen` and `RelationshipLicenseScreen`). Currently, these inputs do not define keyboard actions, forcing users to manually tap on each input field.

#### Proposed Solution
1. In `AuthScreen`, configure text fields:
   - Email: `textInputAction: TextInputAction.next`
   - Password: `textInputAction: TextInputAction.done`
2. In `RelationshipLicenseScreen` (`_buildCreationForm` and `_buildForm`):
   - Configure all text fields (FullName, Nationality, Address, Height, Weight, Blood Type, Eye Color, Conditions) to use `textInputAction: TextInputAction.next` so that hitting "Next" on the soft keyboard shifts focus automatically.
   - Configure the Phone / Mobile field to use `textInputAction: TextInputAction.done` to dismiss the keyboard upon completion.
   - Specify appropriate `keyboardType` values (e.g. `TextInputType.text`, `TextInputType.phone`).

---

## 3. Implementation Blueprint

### 3.1 Directory Structure
We will add new services under the existing `lib/services/` directory:
- `lib/services/auth_service.dart`
- `lib/services/couple_service.dart`
- `lib/services/profile_service.dart`
- `lib/services/supabase_sync_service.dart`

---

## 4. Verification & Testing Plan

### 4.1 Static Analysis
Run `flutter analyze` to ensure there are no syntax errors, unused imports, or broken types.

### 4.2 Manual Walkthrough
1. **Authentication Flow**: Verify email signup, sign-in, Google sign-in, and logout continue to function seamlessly.
2. **Profile & License Forms**: Verify editing names, birthdates, genders, and signatures updates local state and syncs to Supabase.
3. **Keyboard Polish**: Tab through fields in the Relationship License screen and confirm focus shifts correctly.
4. **Real-time Sync**: Verify other features (bucket list, noteit, chat) still receive real-time updates when couple entries change.
