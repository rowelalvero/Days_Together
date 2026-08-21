# God-File Decomposition Plans

**PROPOSED.** Concrete, per-file decomposition plans for the four files the audit confirmed as genuine architectural problems, plus a note on the one file that isn't. Each fails in a *different* way (class count, single-class size, fan-in, misplaced logic), so each gets a different fix — there is no single "split it into smaller files" recipe applied uniformly. Executed in Migration Roadmap Phase 8, after routing (Phase 3) and state-ownership (Phase 5/5b) are settled.

---

## 1. `relationship_license_screen.dart` (5,025 lines) — god by class count

**CURRENT STATE:** 17 top-level declarations in one file: `RelationshipLicenseScreen`/`_RelationshipLicenseScreenState` (`:36`, `:44`), `FlippableLicenseCard`/`_FlippableLicenseCardState` (`:1717`, `:1806`), `_LicenseFront` (`:1954`), `_LicenseBack` (`:2352`), `_CardShell` (`:2656`), `_WatermarkPainter` (`:2745`), `_EditLicenseSheet`/`_EditLicenseSheetState` (`:2814`, `:2825`), `SignaturePainter` (`:3736`), `ScaleSignaturePainter` (`:3781`), `SignatureDrawingDialog`/`_SignatureDrawingDialogState` (`:3896`, `:3917`), `_ExportStudioBottomSheet`/`ExportTemplate` enum/`_ExportStudioBottomSheetState` (`:4079`, `:4103`, `:4105`). Six independent widget families and three painters, none of which need to know about each other, packaged as one file. `_calculateAge()` is duplicated verbatim at `:153` and `:4123`. `_buildQrData()` (`:2415-2474`) hand-builds a delimited text wire format inside a `StatelessWidget`. `_saveToDevice()`/`_shareImage()` (`:4193-4257`, `:4134-4192`) do `RenderRepaintBoundary.toImage` → PNG bytes → temp file → `Gal`/`share_plus` — genuine image-export infrastructure living inside a screen.

**Target structure** (`lib/features/relationship/presentation/license/`):

```
license/
├── license_screen.dart              # RelationshipLicenseScreen + _State (orchestration only)
├── cards/
│   ├── flippable_license_card.dart  # FlippableLicenseCard + _State
│   ├── license_front.dart           # _LicenseFront → LicenseFront (made public)
│   ├── license_back.dart            # _LicenseBack → LicenseBack
│   └── card_shell.dart              # _CardShell → CardShell
├── painters/
│   ├── watermark_painter.dart
│   ├── signature_painter.dart       # SignaturePainter + ScaleSignaturePainter
├── edit/
│   └── edit_license_sheet.dart      # _EditLicenseSheet + _State
├── signature/
│   └── signature_drawing_dialog.dart
└── export/
    └── export_studio_sheet.dart     # _ExportStudioBottomSheet + ExportTemplate + _State
```

**Logic extractions (not just moves):**
- `_calculateAge()` → delete both copies; call the single implementation already consolidated into `DateHelper` in Migration Phase 0.
- `_buildQrData()` → `lib/features/relationship/data/license_qr_codec.dart`, a plain class `LicenseQrCodec` with `encode(LicenseDetails) → String` and `decode(String) → LicenseDetails?`. This is the one piece of this file that needs a **new unit test**: a round-trip test (`encode` then `decode` reproduces the original), since the format is hand-rolled and currently has zero coverage.
- `_saveToDevice()`/`_shareImage()` → `lib/features/relationship/data/image_export_service.dart`, an `ImageExportService` taking a `GlobalKey<State>` (the `RepaintBoundary` key) and exposing `saveToGallery()`/`share()`. This makes the export logic independently testable (mockable `Gal`/`share_plus` calls) and reusable if another feature ever needs "export this widget as an image."

**Validation:** `LicenseQrCodec` round-trip test (new); existing widget behavior otherwise unchanged — this is a pure relocation plus two logic extractions, verified by `flutter analyze` and manual smoke test of the license screen's flip/edit/export/signature flows.

---

## 2. `noteit_screen.dart` (2,571 lines) — god by single-class size

**CURRENT STATE:** Two top-level declarations only — `NoteitScreen` and a single **2,533-line** `_NoteitScreenState`. This is the most extreme single-class god object in the codebase. The state class directly does SharedPreferences persistence (`_saveDraft`/`_loadDraft`, `:149-181`, using the literal key `'noteit_draft_canvas'`), and — the specific problem this decomposition targets — `_sendCanvas()` (`:606-696`) is a five-step, multi-provider transaction embedded in a widget method:

1. Render the canvas to a 1000×1000 PNG (`_controller.renderImage`).
2. Write the PNG to a temp file.
3. Serialize the `CanvasDocument` to JSON.
4. Call `provider.sendCanvas(jsonStr, file.path)`.
5. **Cross-domain mirror:** call `chatProvider.sendMessage('[scrapbook]:${newItem.id}', yourName)` (`:653-655`) — writing into an entirely different feature's data.
6. Clear the SharedPreferences draft (`:660-661`).

No step is transactional with any other; a failure partway through (e.g. step 4 succeeds, step 5 throws) leaves the scrapbook note created but no chat message referencing it, with no recovery path.

**Target structure** (`lib/features/scrapbook/`):

```
scrapbook/
├── presentation/
│   └── noteit_screen.dart           # NoteitScreen + _State, now orchestration-only
├── domain/
│   └── scrapbook_share_use_case.dart  # ScrapbookShareUseCase (see below) — the one domain/ dir in the app, per ADR-009
└── data/
    └── noteit_draft_store.dart      # NoteitDraftStore (wraps SharedPreferences, owns 'noteit_draft_canvas')
```

**The use case (Definition-of-Done item 13):**
```dart
class ScrapbookShareUseCase {
  ScrapbookShareUseCase(this._noteitProvider, this._chatProvider, this._draftStore);
  final NoteitController _noteitProvider;   // post-Phase-6 Riverpod notifier
  final ChatController _chatProvider;
  final NoteitDraftStore _draftStore;

  Future<AppFailure?> share(CanvasDocument doc, {required String yourName}) async {
    // 1-4: render, write temp file, serialize, send — same as today
    // 5: chatProvider.sendMessage(ScrapbookRef(itemId).toChatPayload(), yourName)  — see item 3 below
    // 6: draftStore.clear()
    // Each step's failure is caught and mapped to AppFailure (ADR-011); step 5's
    // failure does NOT roll back step 4 — the note exists either way — but IS
    // surfaced distinctly to the UI ("shared to scrapbook, but couldn't notify chat")
    // rather than silently swallowed, which is the concrete bug this extraction fixes.
  }
}
```

Moving this out of `_NoteitScreenState` makes the five-step sequence independently unit-testable (fake `NoteitController`/`ChatController`/`NoteitDraftStore`) for the first time — today it can only be exercised by actually rendering a widget and tapping a button.

**Validation:** unit tests for `ScrapbookShareUseCase.share()` covering: full success; step 4 (note creation) failure — draft is *not* cleared; step 5 (chat mirror) failure — note *is* kept, distinct error surfaced.

---

## 3. `bento_grid.dart` (2,390 lines) — god by fan-in

**CURRENT STATE:** `BentoGrid` (`:33`, ~2,020 lines) imports **8 providers and 7 screens**, and contains 9 `MaterialPageRoute` push sites — it is the Home tab's composition root and legitimately needs to read from many features, but currently does so with no shared vocabulary. Specifically: it parses the ad-hoc `'[scrapbook]:'` string prefix that `noteit_screen.dart:653` writes (`:1999-2012`), `jsonDecode`s the payload, and switches on an untyped `int?` to pick a display string — with no type connecting the writer and the reader. `_formatRelativeTime` is duplicated within the same file (`:728` and `:2084`, in `BentoGrid` and `_DoodleNotesBentoCardState` respectively). Synchronous `File(...).existsSync()` calls happen during `build()` at `:2295` and `:2325`.

**Target structure:** once Phase 7b relocates `bento_grid.dart` into `lib/features/dashboard/presentation/`, this file's fan-in becomes a legible, correct fact about the dashboard feature (it *should* read from 8 features — that's what a home dashboard is), not evidence of a layering violation. The remaining work is fixing the actual bugs, not restructuring the file's dependency shape:

- **`ScrapbookRef` (Definition-of-Done item 14):** a small, shared type in `lib/features/scrapbook/data/scrapbook_ref.dart`:
  ```dart
  class ScrapbookRef {
    const ScrapbookRef(this.itemId);
    final String itemId;
    String toChatPayload() => 'scrapbook:$itemId';           // stable, versioned prefix
    static ScrapbookRef? fromChatPayload(String raw) { ... }  // null on non-match, no exceptions
  }
  ```
  `noteit_screen.dart`'s (now `ScrapbookShareUseCase`'s) writer and `bento_grid.dart`'s reader both depend on this one type instead of a hand-rolled string convention duplicated at two call sites with no compiler connection between them.
- **`_formatRelativeTime` dedup:** delete both copies, call the single implementation consolidated into `DateHelper` in Migration Phase 0.
- **`File().existsSync()` during build:** replace with a small `FutureProvider`/`FutureBuilder`-backed check computed once and cached, not re-evaluated synchronously on every rebuild.

**Validation:** `ScrapbookRef` round-trip serialization test (new); confirm `grep -rn "'\\[scrapbook\\]:'" lib/` returns 0 after the change.

---

## 4. `relationship_duration_screen.dart` (1,259 lines) — misplaced pure logic

**CURRENT STATE:** the clearest case of extractable pure computation in the codebase. `_buildFunStatistics()` (`:526-580`) defines `countWeekends(start, end)` (`:529-541`) — a `while` loop iterating **day-by-day** from the relationship's start date to today, re-executed on **every rebuild** — and `countOccurrencesOfDate(start, end, month, day)` (`:543-554`), used to count Valentine's Days, Christmases, New Year's, and birthdays. 15 milestone literals (30/100/365/500/1000/… days, anniversary years) are hardcoded at `:663-679`. Two small data classes, `_FunStatItem` (`:1240`) and `_AchievedMilestone` (`:1247`), are declared inside a screen file. The file already imports `DateHelper` (`:13`), which provides equivalent helpers that were bypassed rather than extended.

**Resolution — already substantially handled by Migration Phase 0**, which replaces `countWeekends`/`countOccurrencesOfDate` with closed-form calculations added directly to `DateHelper` (e.g. weekend count via `(totalDays ~/ 7) * 2 + remainder-day-of-week-adjustment`, occurrence count via direct year-range arithmetic instead of iteration). What Phase 8 finishes:

- Move `_FunStatItem`/`_AchievedMilestone` into `lib/features/relationship/domain/` (or `data/`, since they're plain value types, not use-cases) as proper model types.
- Move the 15 hardcoded milestone literals into a `const List<MilestoneDefinition>` in the same location, so they're data, not inline widget-building logic.

**Validation:** already covered by Phase 0's closed-form-vs-loop equivalence test; Phase 8's work here is pure relocation with no new behavior, verified by `flutter analyze` and a manual check of the duration screen's "fun statistics" and milestone sections.

---

## 5. `relationship_profile_screen.dart` (1,652 lines) — confirmed **not** a real problem

**CURRENT STATE:** `RelationshipProfileScreen` (~1,250 lines) plus three small helper classes (`_StatTile`, `PairingOptionsSection`/`_State`). Logic-signal density is the lowest of the five files examined during the audit (20 hits, vs. 60–100+ in the others). The bulk of the length is five multi-hundred-line inline dialog builders (`_showRegenerateRecoveryCodeDialog`, `_showNewRecoveryCodeDialog`, `_showDeleteAccountConfirmation`, `_showUnlinkConfirmation`, `_editProfileDialog`) — genuinely UI code, just verbosely inlined rather than extracted.

**Decision: no structural decomposition.** This file does not get a `presentation/` subdirectory restructure, a use-case, or a repository interaction beyond what Phase 4/5b already provide. The only recommended change, at **low priority** and separable from the rest of this roadmap, is extracting the five dialog bodies into their own widget classes (`RegenerateRecoveryCodeDialog`, etc.) purely for readability — this is a nice-to-have, not a Definition-of-Done item, and can be done opportunistically whenever someone is already working in this file for another reason.

---

## Cross-cutting note on sequencing

All five plans above depend on Migration Phase 5/5b (state ownership) and Phase 3 (routing) being complete first — splitting a screen's UI while its state source or navigation wiring is simultaneously changing underneath it would compound two kinds of risk in one diff. Phase 8 is scheduled last in the roadmap specifically so each of these decompositions is a pure structural move against an already-stable state and routing foundation.
