# Requirements: days_together

**Defined:** 2026-06-19
**Core Value:** Couples can interact and sync their shared memories, moods, and plans in real time with a stable, beautiful, and consistent visual interface.

## v1 Requirements

### Foundation & Cleanup (Phase 1)

- [x] **FOUND-01**: Cancel all Supabase real-time stream subscriptions upon provider disposal.
- [x] **FOUND-02**: Add error logging callbacks to all stream listeners to prevent zone crashes.
- [x] **FOUND-03**: Secure client IDs via build-time `String.fromEnvironment` declarations.
- [x] **FOUND-04**: Fix query crash on `users.created_at` column.
- [x] **FOUND-05**: Implement lazy realtime stream pattern in DailyMoodProvider.
- [x] **FOUND-06**: Constrain username layouts in the settings header avatar row.

### UI/UX Polish (Phase 2)

- [ ] **POL-01**: Migrate all remaining 218 occurrences of hardcoded colors to use dynamic theme color tokens from ThemeProvider.
- [ ] **POL-02**: Normalize spacing in view containers and sized bounds to match the 4px/8px design scale (replacing arbitrary 15, 14, 3, etc. gaps).
- [ ] **POL-03**: Replace generic button copywriting ("Submit", "OK", "Cancel") with specific action labels on onboarding and settings screens.

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Complete |
| FOUND-02 | Phase 1 | Complete |
| FOUND-03 | Phase 1 | Complete |
| FOUND-04 | Phase 1 | Complete |
| FOUND-05 | Phase 1 | Complete |
| FOUND-06 | Phase 1 | Complete |
| POL-01 | Phase 2 | Pending |
| POL-02 | Phase 2 | Pending |
| POL-03 | Phase 2 | Pending |

**Coverage:**
- v1 requirements: 9 total
- Mapped to phases: 9
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-19*
*Last updated: 2026-06-19 after Phase 1 UAT*
