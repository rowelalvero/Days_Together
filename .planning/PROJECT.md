# Project: days_together

## What This Is

A beautiful relationship memory and shared space Flutter application designed for couples. It features a shared timeline, daily mood checking, calendars, notes, note-its, bucket lists, vaults, gift reminders, and custom love themes, backed by Supabase realtime database sync.

## Core Value

Couples can interact and sync their shared memories, moods, and plans in real time with a stable, beautiful, and consistent visual interface.

## Requirements

### Validated

- ✓ **Foundation & Fixes**: Memory leaks, rate limits, layout overflows, and query crashes resolved. — Phase 1

### Active

- [ ] **UI/UX Polish**: Eliminate all hardcoded colors, normalize spacing, and refine copywriting/CTAs. — Phase 2

### Out of Scope

- Multi-partner support (designed strictly for couples, 2 users).

## Context

The application is an existing brownfield codebase that was audited in Phase 1 to fix connection stability, RLS issues, and UI overflow crashes. Phase 2 aims to perform a comprehensive styling and design system cleanup to support dynamic themes without hardcoded color conflicts.

## Constraints

- **Tech Stack**: Flutter (Dart) client + Supabase database & storage backend.
- **Dynamic Themes**: Must preserve theme-independent components while mapping colored widgets to ThemeProvider styles.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Lazy Stream Subscriptions | Prevent Supabase connection rate limit from triggering during background sync. | ✓ Good |
| Safe Fallbacks for Join Date | Handles null registry date since `created_at` does not exist in `users` table. | ✓ Good |
| Constrain Avatar Name Width | Sized layout constraints prevent overflow on large user/partner name strings. | ✓ Good |

---
*Last updated: 2026-06-19 after Phase 1 Verification*

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state
