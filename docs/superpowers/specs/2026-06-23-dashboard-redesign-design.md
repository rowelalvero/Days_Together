# Design Spec: Revamped Dashboard & Bento Grid UI/UX Integration

This document outlines the design specification for porting the premium UI/UX design of the `days-together` web dashboard into the `ashwel_anniversary` Flutter application.

## 1. Goal & Objectives
Enhance the Flutter app's Home Dashboard with a visually striking, premium glassmorphism theme, ticking clock widgets, dynamic insights, partner presence cards, memory highlights, and a single-column Bento Grid of quick-access previews linking to key features.

---

## 2. Visual Theme & Layout

### 2.1 Ambient Blur Blobs & Grid Pattern
*   **Layer 1 (Background)**: The existing theme gradient is drawn.
*   **Layer 2 (Ambient Blobs)**: Two circular gradient containers with 10%–15% opacity positioned at `top: -50, left: -50` (primary theme color) and `bottom: 100, right: -50` (accent theme color). These will be wrapped in `ImageFilter.blur(sigmaX: 100, sigmaY: 100)` to create soft organic glowing spots.
*   **Layer 3 (Grid Overlay)**: A light repeating grid pattern drawn using a custom painter overlay with `Colors.white.withOpacity(0.015)`.

### 2.2 Glassmorphism Components
*   Use the `GlassContainer` widget for all cards on the dashboard.
*   Enforce borders with `Border.all(color: Colors.white.withOpacity(0.08), width: 1.5)`.
*   Maintain a default background color of `Colors.white.withOpacity(0.05)` or `Colors.black.withOpacity(0.2)`.

---

## 3. Dashboard Component Architecture

The redesigned dashboard will reside in `lib/widgets/dashboard/` to maintain modularity:

### 3.1 `insights_banner.dart`
*   **Description**: Auto-scrolling horizontal banner showing dynamic statistics and tips.
*   **Data Sources**:
    *   Total memories from `TimelineProvider`
    *   Completion percentage from `BucketListProvider`
    *   Milestone progress from `RelationshipProvider`
    *   Unread chat messages count from `LoveChatProvider`
*   **Logic**: Loops every 6 seconds using a periodic `Timer`. Tapping chevrons enables manual navigation.

### 3.2 `partner_presence_card.dart`
*   **Description**: Displays partner's avatar, online indicator status, custom status text, and triggers love taps.
*   **Avatar Pulse**: Pulsing ring utilizing standard Flutter animation controllers. Emerald green if `relationshipProvider.isPartnerOnline` is true, otherwise grey.
*   **Editable Status**: Displays partner's status (`relationshipProvider.partnerConditions` / `relationshipProvider.yourConditions`). Allows clicking to edit the user's status via a dialog, saving to `relationshipProvider.setConditionsAndDateIssued(...)`.
*   **Love Tap**: Glass button with glowing heart. Tapping triggers a local floating heart animation overlay (`burst_hearts.dart`) and appends a beacon message to `LoveChatProvider`.
*   **Demo Toggle**: Adds a small local button to toggle the simulated online state.

### 3.3 `milestone_card.dart`
*   **Description**: Displays the next relationship milestone progress.
*   **UI**: Renders a circular progress indicator with a custom text percentage and days-left countdown, matching the web card style.

### 3.4 `memory_highlight_carousel.dart`
*   **Description**: Horizontal swipeable carousel of recent memories.
*   **UI**: Each card shows memory title, date, location, and a mood emoji. Uses `PageController`. Displays the memory image if `imagePath` or `networkImageUrl` is present.

### 3.5 `relationship_statistics.dart`
*   **Description**: A 2x3 grid displaying key metrics.
*   *   **Total Memories**: `timelineProvider.timelineItems.length`
    *   **Total Photos**: Count of photos in memories + photos in `VaultProvider`
    *   **Timeline Years**: Rounded float of years together
    *   **Bucket Completed**: Completion fraction `${completedItems}/${totalItems}`
    *   **Capsules**: Total capsules from `TimeCapsuleProvider`
    *   **Shared Notes**: Total notes from `NoteitProvider`

### 3.6 `bento_grid.dart`
*   **Description**: Displays 9 quick-access preview cards in a single-column list.
*   **Preview Cards**:
    1.  **NoteIt Workspace**: Displays latest note content, author, and timestamp.
    2.  **Calendar Timeline**: Displays next event, date, countdown, and a "SOON" badge.
    3.  **Daily Mood**: Displays side-by-side mood emojis with a "SYNCED" glow connector.
    4.  **Emotional Map**: Embedded mini `LineChart` sparkline drawn using `fl_chart` based on `DailyMoodProvider.recentMoods`.
    5.  **Daily Sync Question**: Displays active sync question and answer status badges for both users.
    6.  **Bucket List**: Displays completions progress bar and next target goal.
    7.  **Time Capsules**: Displays nearest locked capsule and a live ticking countdown.
    8.  **Crypto Vault**: Displays document list (masked) and lock state.
    9.  **Love Chat Space**: Displays last message preview, sender, relative time, and unread bubble.

### 3.7 `recent_activity_feed.dart`
*   **Description**: Renders dynamic feed events from all providers.

---

## 4. Verification Plan
*   **Navigation Check**: Verify tapping each Bento card navigates to the correct target screen.
*   **Live Ticking**: Check that the stopwatch hours/minutes/seconds tick every second.
*   **Demo Status Toggle**: Click "Demo Toggle" on the partner card and ensure it toggles the online pulse.
*   **Haptics & Animation**: Verify Love Tap triggers haptic vibrations and overlays heart animations.
