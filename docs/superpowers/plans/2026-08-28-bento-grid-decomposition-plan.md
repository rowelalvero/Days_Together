# BentoGrid God-Widget Decomposition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose the 2,318-line `bento_grid.dart` into 9 modular cards under `lib/features/dashboard/presentation/cards/`.

**Tech Stack:** Flutter, Dart, Riverpod 2.x.

---

### Task 1: Extract Doodle Notes & Shared Calendar Cards
- Create `lib/features/dashboard/presentation/cards/doodle_notes_bento_card.dart`
- Create `lib/features/dashboard/presentation/cards/shared_calendar_bento_card.dart`
- [ ] **Step 1: Implement DoodleNotesBentoCard**
- [ ] **Step 2: Implement SharedCalendarBentoCard**

---

### Task 2: Extract Daily Mood & Emotional Map Cards
- Create `lib/features/dashboard/presentation/cards/daily_mood_bento_card.dart`
- Create `lib/features/dashboard/presentation/cards/emotional_map_bento_card.dart`
- [ ] **Step 1: Implement DailyMoodBentoCard**
- [ ] **Step 2: Implement EmotionalMapBentoCard**

---

### Task 3: Extract Daily Sync & Bucket List Cards
- Create `lib/features/dashboard/presentation/cards/daily_sync_bento_card.dart`
- Create `lib/features/dashboard/presentation/cards/bucket_list_bento_card.dart`
- [ ] **Step 1: Implement DailySyncBentoCard**
- [ ] **Step 2: Implement BucketListBentoCard**

---

### Task 4: Extract Time Capsule, Secret Vault & Love Chat Cards
- Create `lib/features/dashboard/presentation/cards/time_capsule_bento_card.dart`
- Create `lib/features/dashboard/presentation/cards/secret_vault_bento_card.dart`
- Create `lib/features/dashboard/presentation/cards/love_chat_bento_card.dart`
- [ ] **Step 1: Implement TimeCapsuleBentoCard**
- [ ] **Step 2: Implement SecretVaultBentoCard**
- [ ] **Step 3: Implement LoveChatBentoCard**

---

### Task 5: Refactor BentoGrid & Verification
- Modify `lib/features/dashboard/presentation/bento_grid.dart`
- [ ] **Step 1: Refactor BentoGrid to assemble the 9 card components**
- [ ] **Step 2: Verify zero broken imports or architecture violations**
