# NoteitScreen God-Widget Decomposition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose the 2,581-line `noteit_screen.dart` into clean, modular components inside `lib/features/scrapbook/presentation/`.

**Architecture:** Split into history panel, background dialog, floating toolbar, brush properties sheet, text properties sheet, and canvas viewport.

**Tech Stack:** Flutter, Dart, Riverpod 2.x, FlutterPainter.

---

### Task 1: Extract History Panel & Sync Badge
- Create `lib/features/scrapbook/presentation/components/noteit_history_panel.dart`
- [ ] **Step 1: Implement NoteitHistoryPanel and supporting badges**
- [ ] **Step 2: Verify component builds independently**

---

### Task 2: Extract Background Settings Dialog
- Create `lib/features/scrapbook/presentation/dialogs/noteit_background_dialog.dart`
- [ ] **Step 1: Implement NoteitBackgroundDialog**
- [ ] **Step 2: Verify dialog renders with custom backgrounds**

---

### Task 3: Extract Floating Toolbar
- Create `lib/features/scrapbook/presentation/components/noteit_floating_toolbar.dart`
- [ ] **Step 1: Implement NoteitFloatingToolbar**
- [ ] **Step 2: Connect toolbar actions**

---

### Task 4: Extract Property Sheets
- Create `lib/features/scrapbook/presentation/sheets/noteit_brush_properties_panel.dart`
- Create `lib/features/scrapbook/presentation/sheets/noteit_text_properties_panel.dart`
- [ ] **Step 1: Implement NoteitBrushPropertiesPanel**
- [ ] **Step 2: Implement NoteitTextPropertiesPanel**

---

### Task 5: Extract Canvas Viewport & Refactor NoteitScreen
- Create `lib/features/scrapbook/presentation/components/noteit_canvas_viewport.dart`
- Modify `lib/screens/together/noteit_screen.dart`
- [ ] **Step 1: Implement NoteitCanvasViewport**
- [ ] **Step 2: Refactor NoteitScreen to compose the extracted components**
- [ ] **Step 3: Run full tests to verify zero regressions**
