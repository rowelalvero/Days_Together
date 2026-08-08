# Days Together — Build and Run Guide

## Prerequisites
- Flutter SDK 3.10.0 or higher
- Android Studio / Xcode for device builds

## Environment Configuration

Days Together uses compile-time environment variables defined via `--dart-define` to configure Supabase and Google Auth parameters.

### Standard Build / Run Command

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-supabase-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-supabase-anon-key \
  --dart-define=GOOGLE_CLIENT_ID_WEB=your-google-web-client-id \
  --dart-define=GOOGLE_CLIENT_ID_IOS=your-google-ios-client-id
```

### Production Release Build

```bash
# Android App Bundle
flutter build appbundle \
  --dart-define=SUPABASE_URL=https://your-supabase-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-supabase-anon-key \
  --dart-define=GOOGLE_CLIENT_ID_WEB=your-google-web-client-id \
  --dart-define=GOOGLE_CLIENT_ID_IOS=your-google-ios-client-id

# iOS IPA
flutter build ipa \
  --dart-define=SUPABASE_URL=https://your-supabase-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-supabase-anon-key \
  --dart-define=GOOGLE_CLIENT_ID_WEB=your-google-web-client-id \
  --dart-define=GOOGLE_CLIENT_ID_IOS=your-google-ios-client-id
```

### VS Code Launch Configuration (`.vscode/launch.json`)

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Days Together (Dev)",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=SUPABASE_URL=https://mfyfbzyfzlhrpcfxtlmu.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=your-key",
        "--dart-define=GOOGLE_CLIENT_ID_WEB=1043515146762-s4pm3ed9r5aqface2457jafleen4q1tg.apps.googleusercontent.com"
      ]
    }
  ]
}
```

> **Security Note:** Never include `service_role` keys in Flutter client builds. All client database access is restricted by Supabase Row-Level Security (RLS).
