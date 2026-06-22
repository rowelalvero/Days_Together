# Android Permissions Integration Design

We are implementing a uniform, premium permission handling system throughout the application for Camera, Storage/Photos, and Notifications.

## Goal
Gracefully check and request permissions when accessing Android device features (camera, gallery/storage, notifications) and handle cases where they are permanently denied by directing the user to App Settings via a premium glassmorphic dialog.

## Proposed Changes

### 1. Dependencies Setup
Add `permission_handler: ^11.3.1` to [pubspec.yaml](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/pubspec.yaml).

### 2. Android Manifest Configuration
Add permission declarations to [AndroidManifest.xml](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/android/app/src/main/AndroidManifest.xml):
- `android.permission.CAMERA`
- `android.permission.READ_EXTERNAL_STORAGE` (max SDK 32)
- `android.permission.WRITE_EXTERNAL_STORAGE` (max SDK 29)
- `android.permission.READ_MEDIA_IMAGES` (Android 13+)
- `android.permission.POST_NOTIFICATIONS` (Android 13+)

### 3. Centralized Permission Service
Create [permission_service.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/services/permission_service.dart) to define `PermissionService`:
- `Future<bool> requestCameraPermission(BuildContext context)`
- `Future<bool> requestPhotosPermission(BuildContext context)`
- `Future<bool> requestNotificationPermission(BuildContext context)`
- Shared method `_handlePermissionRequest(BuildContext context, Permission permission, String featureName, String rationale)`

### 4. Glassmorphic Permission Dialog
Create [glass_permission_dialog.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/widgets/glass_permission_dialog.dart) featuring:
- Frosted glass container using `BackdropFilter` and translucent borders.
- Clear feature icon, title, description, and explanation of why the permission is required.
- Action buttons: "Cancel" and "Open Settings" (triggers `openAppSettings()`).

### 5. Integration Points

#### Timeline Memory Creation
- File: [timeline_provider.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/providers/timeline_provider.dart)
- Action: Guard `pickImage()` by checking photo permissions. Note: Since `TimelineProvider` is a ChangeNotifier provider and may not have a BuildContext in `pickImage()`, we will pass the `BuildContext` as an argument to `pickImage(BuildContext context)`.

#### Private Vault Items
- File: [vault_provider.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/providers/vault_provider.dart)
- Action: Guard `pickImage()` by checking photo permissions. Similar to timeline, we will pass the `BuildContext` to `pickImage(BuildContext context)`.

#### Love Notes (Drawing & Photo attachments)
- File: [noteit_screen.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/screens/together/noteit_screen.dart)
- Action: Request camera permission when opening camera, and photos permission when opening gallery in `_pickImage(ImageSource source)`.

#### Profile Settings & Avatar Customization
- Files:
  - [settings_tab.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/screens/settings_tab.dart)
  - [avatar_creation_screen.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/screens/onboarding/avatar_creation_screen.dart)
- Action: Request photos permission before launching gallery selection.

#### Relationship License
- File: [relationship_license_screen.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/screens/together/relationship_license_screen.dart)
- Action: Request photos permission before uploading a license background.

#### Push Notifications
- File: [notification_service.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/services/notification_service.dart)
- Action: Supplement FCM's native permission request with a request for the `Permission.notification` runtime permission on Android 13+.

---

## Verification Plan

### Automated Verification
- Run `flutter analyze` to ensure code builds without compile or lint issues.
- Run `flutter test` to ensure existing model and provider tests pass without regressions.

### Manual Verification
- Deploy to Android simulator/device.
- Trigger permissions request:
  - Accept permission and verify feature executes successfully.
  - Deny permission and verify the action stops.
  - Deny permanently and verify custom `GlassPermissionDialog` displays and successfully redirects to Android App Settings.
