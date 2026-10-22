# Code Review Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve critical and high-priority code quality, memory management, reactivity, and architectural issues across the Days Together app.

**Architecture:** Refactor transient dialogs to self-contained stateful widgets with explicit controller lifecycles; replace non-reactive `ref.read` in widget build trees with `ref.watch`; decouple `shared/` dialogs from `features/` layer to satisfy Rule 12; replace empty `catch (_) {}` blocks with robust error logging and state updates.

**Tech Stack:** Flutter, Dart, Riverpod 2.x, Supabase Flutter.

---

### Task 1: Fix Dialog Controller Memory Leaks

**Files:**
- Modify: `lib/screens/studio/ai_love_letter_screen.dart`
- Modify: `lib/screens/together/vault_screen.dart`

- [ ] **Step 1: Refactor `_promptForPin` in `ai_love_letter_screen.dart` to use a dedicated `_PinPromptDialog` widget**
- [ ] **Step 2: Refactor `_showWriteLetterDialog` in `vault_screen.dart` to use a dedicated `_WriteLetterDialog` widget**
- [ ] **Step 3: Verify dialogs build and dismiss without leaks**

---

### Task 2: Fix Non-Reactive `ref.read` in Widget Build Trees

**Files:**
- Modify: `lib/screens/together/noteit_screen.dart`
- Modify: `lib/features/relationship/presentation/license/license_screen.dart`
- Modify: `lib/screens/love_story_screen.dart`
- Modify: `lib/screens/together/love_chat_screen.dart`

- [ ] **Step 1: In `noteit_screen.dart`, update `_buildToolbarButton` and `_buildColorCircle` to watch `themeControllerProvider`**
- [ ] **Step 2: In `license_screen.dart`, update `_selectCreateDate` to watch or derive theme**
- [ ] **Step 3: In `love_story_screen.dart`, update `_buildTimelineScrubber` to watch `timelineControllerProvider`**
- [ ] **Step 4: In `love_chat_screen.dart`, update `_buildNoteitCanvas` to watch `noteitControllerProvider`**

---

### Task 3: Architecture Layering - Decouple `shared/` from `features/` (Rule 12)

**Files:**
- Modify: `lib/shared/glass_permission_dialog.dart`
- Modify: `lib/shared/safe_loading_dialog.dart`
- Test: `test/architecture_test.dart`

- [ ] **Step 1: Remove `theme_controller.dart` import from `glass_permission_dialog.dart`**
- [ ] **Step 2: Remove `theme_controller.dart` and `theme_manager.dart` imports from `safe_loading_dialog.dart`**
- [ ] **Step 3: Run `flutter test test/architecture_test.dart` to verify Rule 12 compliance**

---

### Task 4: Error Handling & Resilience Across Controllers

**Files:**
- Modify: `lib/features/bucket_list/bucket_list_controller.dart`
- Modify: `lib/features/calendar/calendar_controller.dart`
- Modify: `lib/features/chat/love_chat_controller.dart`
- Modify: `lib/features/mood/daily_mood_controller.dart`
- Modify: `lib/features/gift_reminders/gift_reminder_controller.dart`
- Modify: `lib/features/love_studio/time_capsule_controller.dart`
- Modify: `lib/features/relationship/license_controller.dart`
- Modify: `lib/features/scrapbook/noteit_controller.dart`

- [ ] **Step 1: Add structured logging (`debugPrint`) and state error capture to `bucket_list_controller.dart`**
- [ ] **Step 2: Add structured logging and state error capture to `calendar_controller.dart` and `gift_reminder_controller.dart`**
- [ ] **Step 3: Add structured logging and state error capture to `love_chat_controller.dart` and `noteit_controller.dart`**
- [ ] **Step 4: Add structured logging and state error capture to `daily_mood_controller.dart`, `time_capsule_controller.dart`, and `license_controller.dart`**

---

### Task 5: Full Regression Testing

- [ ] **Step 1: Run all unit and controller tests**
- [ ] **Step 2: Run security adversarial tests**
- [ ] **Step 3: Verify zero regressions**
