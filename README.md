# 💖 Days Together 💖

[![Flutter](https://img.shields.io/badge/Flutter-^3.10.0-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Portfolio](https://img.shields.io/badge/Developer%20Portfolio-Vercel-black?logo=vercel&logoColor=white)](https://myportfolio-vxf8.vercel.app/)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20Web-blue)](#)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](#)

**Days Together** is a beautiful, premium, and real-time synchronized relationship timeline and shared memory space designed exclusively for couples (2 users). Built with **Flutter (Dart)** and backed by a robust **Supabase** backend with real-time stream synchronization, it provides a safe, gorgeous, and interactive vault for a couple's shared journey.

Check out my developer portfolio [here](https://myportfolio-vxf8.vercel.app/) to view more projects and details.


---

## 🌟 Key Features

### 📖 Love Story & Timeline
- **Shared Memories:** Document special moments with titles, descriptions, and uploaded images.
- **Interactive Feed:** A sleek vertical timeline showcasing your journey together.
- **Optimized Real-time Sync:** Synchronized instantly between both partners.

### 🎨 Premium Dynamic Themes (Glassmorphism)
Experience a stunning visual design using harmonious color schemes and subtle glassmorphic elements:
- **Midnight Glass (Default):** Deep midnight dark theme with vivid rose accents.
- **Azure Liquid:** Elegant oceanic blues with refreshing teal glow accents.
- **Rose Quartz:** A soft romantic warm pink and wine theme.
- **Neon Violet:** Rich cybernetic purples and violet neon accents.

### 🔒 Couple Vault & Time Capsules
- **Shared Vault:** Store private pictures, letters, and memorable snapshots securely.
- **Time Capsule:** Lock text notes, images, or files in digital capsules configured to unlock only on specified future dates.

### 📅 Shared Calendar & Gift Reminders
- **Date Calendar:** Add, schedule, and view upcoming dates, trips, and plans.
- **Gift Registry:** Track gift ideas, special occasions, and set local reminders so you never forget an important event or anniversary.

### ✍️ Note-Its & Shared Bucket Lists
- **Note-Its:** Pin sweet, colorful virtual sticky notes to your partner's workspace.
- **Bucket List:** Brainstorm relationship goals and check them off together, tracking your shared completion progress.

### 💌 AI-Generated Love Letters
- **Sentiment Synthesis:** Generate highly customizable, romantic love letters modeled on your shared timeline memories and moods.

### 🎫 Relationship License & Topic Cards
- **Relationship License:** Customize and "sign" a fun relationship certificate complete with heights, weights, Nationalities, and digital signatures.
- **Topic Cards:** Jumpstart late-night conversations with structured quiz-like cards and pairing questions.

### 🎵 Background Soundscapes
- **Lofi & Romantic Music:** Loop sweet background soundtrack files (`assets/music/`) to enhance the cozy shared mood.

---

## 🛠 Tech Stack & Libraries

- **Framework:** [Flutter (Dart SDK ^3.10.0)](https://flutter.dev)
- **State Management:** [Provider](https://pub.dev/packages/provider) for clean, decoupled logic and UI rebuilds.
- **Database & Auth:** [Supabase Flutter](https://pub.dev/packages/supabase_flutter) for database CRUD, real-time stream channels, and Google Sign-In authentication.
- **Graphics & Animation:**
  - [Lottie](https://pub.dev/packages/lottie) for rich vector animations.
  - [Shimmer](https://pub.dev/packages/shimmer) for sleek skeleton loaders.
  - [Animations](https://pub.dev/packages/animations) for material design transitions.
  - [Confetti](https://pub.dev/packages/confetti) for celebrating milestones.
- **Hardware Integrations:**
  - [Sensors Plus](https://pub.dev/packages/sensors_plus) for interactive gestures (e.g., Shake to Hug).
- **Utility Libraries:** `google_fonts`, `image_picker`, `audioplayers`, `uuid`, `fl_chart`, `qr_flutter`, `gal`, `flutter_local_notifications`.

---

## 📁 Project Architecture

The codebase is organized following a clean, modular structure:

```
lib/
├── models/         # Data models mapping database tables (BucketList, Mood, Calendar, Vault, etc.)
├── providers/      # ChangeNotifiers orchestrating business logic, Supabase stream listeners, and themes
├── repositories/   # Data fetching layers (e.g. TimelineRepository)
├── screens/        # UI Screen layers
│   ├── onboarding/ # Welcome, login, couple-pairing code screens, and avatar creations
│   ├── settings/   # Couple profiles and app settings
│   ├── studio/     # AI letters, Time capsules, and Insights tabs
│   └── together/   # Vault, Bucket list, Love meter, Calendar, License, and Note-its tabs
├── services/       # Core service abstractions (AI synthesis, Background Music Player)
├── themes/         # LoveStoryTheme definitions and ThemeManager configurations
└── widgets/        # Reusable custom UI components (Heartbursts, GlassContainers, Shimmer loaders, etc.)
```

---

## 🚀 Setup & Local Installation

### Prerequisites
1. Installed [Flutter SDK](https://docs.flutter.dev/get-started/install) (matching version defined in `pubspec.yaml`).
2. A [Supabase](https://supabase.com) project initialized.

### 1. Database Initialization
Ensure your Supabase project contains the appropriate tables and storage buckets:
- **Tables:** `users`, `couples`, `pairing_codes`, `timeline_items`, `vault_items`, `bucket_list`, `calendar_events`, `moods`, `daily_questions`, `gift_reminders`, `love_notes`, `license_details`, `topic_cards`, `time_capsules`.
- **Storage Buckets:** `avatars`, `vault-photos`.

### 2. Configure Environment Variables
Client IDs and Supabase credentials are secured using build-time environment declarations.
Create or pass the following environment configurations when compiling/running:

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_PROJECT_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Alternatively, configure your local IDE (`launch.json` in VS Code or Run Configuration in Android Studio) to pass these declarations.

### 3. Fetch Dependencies
Install the required packages:
```bash
flutter pub get
```

### 4. Run the Project
Launch on your connected mobile device, emulator, or browser:
```bash
flutter run
```

---

## 🔒 Security & Performance Features

- **Lazy Stream Subscriptions:** Reduces network overhead and avoids hitting database rate limits by disposing real-time listeners during widget de-allocation.
- **Robust Row Level Security (RLS):** Table policies ensure data can only be queried or mutated by the two authenticated partners sharing the corresponding `couple_code`.
- **Horizontal Overflow Constraints:** Username layouts and settings badges are dynamically constrained to prevent UI clipping on varying device widths.

---

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
