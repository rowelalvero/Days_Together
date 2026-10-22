# Relationship Duration Screen Decomposition Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose the 1,212-line monolithic `relationship_duration_screen.dart` into 7 focused presentation components and a lean ~160-line orchestrator screen under `lib/features/relationship/presentation/duration/components/`.

**Architecture:** Extract each visual section (Duration Breakdown, Live Stopwatch, Next Milestone Progress, Anniversary Countdown, Journey Fun Facts, Milestones Timeline, and First Memory Highlight) into isolated, self-contained widgets. Maintain 100% pixel-perfect UI fidelity, animation curves, responsive behavior, and zero broken imports.

**Tech Stack:** Flutter, Flutter Riverpod, GoRouter, Intl.

---

## Global Constraints

- Never break existing imports or route definitions.
- Maintain architecture Rule 12 (no cross-boundary dependencies from core/shared to features).
- Ensure all controllers and timers are disposed cleanly (`_LiveStopwatchWidgetState` timer and animation controller).
- Preserve existing styling, font sizes, glassmorphism, animations, and color palettes.

---

## Task Structure

### Task 1: Duration Breakdown & Live Stopwatch Components
**Files:**
- Create: `lib/features/relationship/presentation/duration/components/duration_breakdown_section.dart`
- Create: `lib/features/relationship/presentation/duration/components/live_stopwatch_card.dart`

**Interfaces:**
- `DurationBreakdownSection`: takes `WorkspaceState workspace` and `LoveStoryTheme theme`.
- `LiveStopwatchCard`: takes `DateTime startDate` and `LoveStoryTheme theme`.

- [ ] **Step 1: Create `duration_breakdown_section.dart`**
- [ ] **Step 2: Create `live_stopwatch_card.dart`**
- [ ] **Step 3: Verify no syntax errors in new files**

---

### Task 2: Milestone Progress & Anniversary Countdown Components
**Files:**
- Create: `lib/features/relationship/presentation/duration/components/next_milestone_card.dart`
- Create: `lib/features/relationship/presentation/duration/components/anniversary_countdown_card.dart`

**Interfaces:**
- `NextMilestoneCard`: takes `WorkspaceState workspace` and `LoveStoryTheme theme`.
- `AnniversaryCountdownCard`: takes `DateTime startDate`, `int currentYears`, and `LoveStoryTheme theme`.

- [ ] **Step 1: Create `next_milestone_card.dart`**
- [ ] **Step 2: Create `anniversary_countdown_card.dart`**
- [ ] **Step 3: Verify no syntax errors in new files**

---

### Task 3: Journey Fun Facts, Milestones Timeline, & First Memory Highlight Components
**Files:**
- Create: `lib/features/relationship/presentation/duration/components/journey_fun_facts_grid.dart`
- Create: `lib/features/relationship/presentation/duration/components/milestones_achieved_timeline.dart`
- Create: `lib/features/relationship/presentation/duration/components/first_memory_highlight_card.dart`

**Interfaces:**
- `JourneyFunFactsGrid`: takes `DateTime startDate`, `WorkspaceState workspace`, `LicenseDetails license`, and `LoveStoryTheme theme`.
- `MilestonesAchievedTimeline`: takes `DateTime startDate`, `int totalDays`, and `LoveStoryTheme theme`.
- `FirstMemoryHighlightCard`: takes `TimelineState tp` and `LoveStoryTheme theme`.

- [ ] **Step 1: Create `journey_fun_facts_grid.dart`**
- [ ] **Step 2: Create `milestones_achieved_timeline.dart`**
- [ ] **Step 3: Create `first_memory_highlight_card.dart`**

---

### Task 4: Refactor `relationship_duration_screen.dart` & Project-wide Verification
**Files:**
- Modify: `lib/screens/together/relationship_duration_screen.dart`

- [ ] **Step 1: Refactor `relationship_duration_screen.dart` to compose the 7 extracted components (~160 LOC)**
- [ ] **Step 2: Run AST / import validation script across all project Dart files**
- [ ] **Step 3: Verify architecture Rule 12 & stateful controller lifecycles**
