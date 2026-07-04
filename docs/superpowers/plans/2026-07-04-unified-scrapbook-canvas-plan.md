# Unified Scrapbook Canvas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify Doodle, Text Note, and Photo features into a single, interactive, square canvas editor that supports Pencil/Pen/Marker/Eraser drawing, a paint bucket tool, custom color pickers, and Messenger-style draggable, pinch-to-scale rich text overlays.

**Architecture:** We use a stack-based canvas architecture where the background is a solid color or photo, drawing is rasterized onto an offscreen image (supporting BlendMode.clear erasing and BFS flood fill), and text overlays are positioned widgets that handle gesture drag & scale. The entire canvas state is serialized into JSON and stored in the `content` field.

**Tech Stack:** Flutter, Provider, SharedPreferences, Supabase Storage/Database, ImagePicker, custom BFS flood-fill.

## Global Constraints
- Canvas MUST be square (1:1 aspect ratio).
- Maintain complete backward compatibility for old drawing and text note types.
- Ensure all drawings are drawn on a fixed coordinate system (e.g. 600x600 pixels) to render identically across different screen sizes.

---

### Task 1: Extend Data Models & Add Serialization Tests

**Files:**
- Modify: [noteit_model.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/models/noteit_model.dart)
- Create: [noteit_model_test.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/test/noteit_model_test.dart)

**Interfaces:**
- Produces: `CanvasData`, `CanvasTextOverlay`, `CanvasStroke`, `CanvasPoint` helper classes and JSON serialization methods.

- [ ] **Step 1: Create the failing unit test**

Create the file `test/noteit_model_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/models/noteit_model.dart';

void main() {
  test('CanvasData serialization and backward compatibility', () {
    // 1. Test serialization of new unified canvas JSON
    final jsonStr = '{"version":1,"backgroundColor":4279069466,"drawingLayer":"base64data","textOverlays":[{"id":"1","text":"Love","x":100.0,"y":200.0,"scale":1.5,"fontSize":16.0,"color":4294967295,"backgroundColor":0,"isBold":true,"isItalic":false,"isUnderline":false,"alignment":"center"}]}';
    
    expect(jsonStr, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/noteit_model_test.dart`
Expected: PASS (as a dummy check) or FAIL if there are unresolved import issues.

- [ ] **Step 3: Implement data structures in `noteit_model.dart`**

Modify `lib/models/noteit_model.dart` to define:
```dart
class CanvasPoint {
  final double x;
  final double y;
  CanvasPoint(this.x, this.y);
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory CanvasPoint.fromJson(Map<String, dynamic> json) =>
      CanvasPoint((json['x'] as num).toDouble(), (json['y'] as num).toDouble());
}

class CanvasStroke {
  final List<CanvasPoint> points;
  final int color;
  final double strokeWidth;
  final String penType; // 'pen' | 'pencil' | 'marker' | 'eraser'
  CanvasStroke({required this.points, required this.color, required this.strokeWidth, required this.penType});
  Map<String, dynamic> toJson() => {'points': points.map((p) => p.toJson()).toList(), 'color': color, 'strokeWidth': strokeWidth, 'penType': penType};
  factory CanvasStroke.fromJson(Map<String, dynamic> json) => CanvasStroke(
        points: (json['points'] as List).map((p) => CanvasPoint.fromJson(p)).toList(),
        color: json['color'] as int,
        strokeWidth: (json['strokeWidth'] as num).toDouble(),
        penType: json['penType'] as String? ?? 'pen',
      );
}

class CanvasTextOverlay {
  final String id;
  final String text;
  final double x;
  final double y;
  final double scale;
  final double fontSize;
  final int color;
  final int backgroundColor;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String alignment; // 'left' | 'center' | 'right'

  CanvasTextOverlay({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.scale,
    required this.fontSize,
    required this.color,
    required this.backgroundColor,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.alignment,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'x': x,
        'y': y,
        'scale': scale,
        'fontSize': fontSize,
        'color': color,
        'backgroundColor': backgroundColor,
        'isBold': isBold,
        'isItalic': isItalic,
        'isUnderline': isUnderline,
        'alignment': alignment,
      };

  factory CanvasTextOverlay.fromJson(Map<String, dynamic> json) => CanvasTextOverlay(
        id: json['id'] as String,
        text: json['text'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        scale: (json['scale'] as num? ?? 1.0).toDouble(),
        fontSize: (json['fontSize'] as num? ?? 20.0).toDouble(),
        color: json['color'] as int,
        backgroundColor: json['backgroundColor'] as int? ?? 0,
        isBold: json['isBold'] as bool? ?? false,
        isItalic: json['isItalic'] as bool? ?? false,
        isUnderline: json['isUnderline'] as bool? ?? false,
        alignment: json['alignment'] as String? ?? 'center',
      );
}

class CanvasData {
  final int version;
  final int backgroundColor;
  final String? backgroundImage;
  final String? drawingLayer; // Base64 PNG representation
  final List<CanvasTextOverlay> textOverlays;

  CanvasData({
    this.version = 1,
    required this.backgroundColor,
    this.backgroundImage,
    this.drawingLayer,
    required this.textOverlays,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'backgroundColor': backgroundColor,
        'backgroundImage': backgroundImage,
        'drawingLayer': drawingLayer,
        'textOverlays': textOverlays.map((o) => o.toJson()).toList(),
      };

  factory CanvasData.fromJson(Map<String, dynamic> json) => CanvasData(
        version: json['version'] as int? ?? 1,
        backgroundColor: json['backgroundColor'] as int,
        backgroundImage: json['backgroundImage'] as String?,
        drawingLayer: json['drawingLayer'] as String?,
        textOverlays: (json['textOverlays'] as List? ?? [])
            .map((o) => CanvasTextOverlay.fromJson(o))
            .toList(),
      );

  static bool isJson(String? data) {
    if (data == null) return false;
    return data.trim().startsWith('{') && data.trim().endsWith('}');
  }
}
```

- [ ] **Step 4: Update test to verify correctness**

Modify the unit test in `test/noteit_model_test.dart` to fully serialize and deserialize a `CanvasData` object, verifying all field values match.
Run: `flutter test test/noteit_model_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

Run:
```bash
git add lib/models/noteit_model.dart test/noteit_model_test.dart
git commit -m "feat: add CanvasData models and serialization tests"
```

---

### Task 2: Sync and Provider Support

**Files:**
- Modify: [noteit_provider.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/providers/noteit_provider.dart)
- Modify: [noteit_sync_manager.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/services/noteit_sync_manager.dart)

**Interfaces:**
- Consumes: `CanvasData` from Task 1.
- Produces: `sendCanvas(String jsonContent, String? localImagePath)` method in `NoteitProvider` and generic image uploading in `NoteitSyncManager`.

- [ ] **Step 1: Update NoteitSyncManager image upload logic**

In `lib/services/noteit_sync_manager.dart`, locate lines 242-243:
```dart
      // Handle file uploads for photo types
      if (task.type == NoteitType.photo && task.imagePath != null) {
```
Modify it to trigger image upload for any task where `imagePath` is not null:
```dart
      // Handle file uploads for any task with local image path
      if (task.imagePath != null) {
```

- [ ] **Step 2: Add sendCanvas to NoteitProvider**

Add the following function to `NoteitProvider` in `lib/providers/noteit_provider.dart`:
```dart
  Future<void> sendCanvas(String jsonContent, String? localImagePath) async {
    final noteId = const Uuid().v4();
    String? finalLocalPath;
    
    if (localImagePath != null) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'noteit_canvas_${DateTime.now().millisecondsSinceEpoch}.jpg';
        finalLocalPath = '${directory.path}/$fileName';
        await File(localImagePath).copy(finalLocalPath);
      } catch (e) {
        debugPrint('NoteitProvider: Failed to copy canvas background: $e');
      }
    }

    final newItem = NoteitItem(
      id: noteId,
      type: NoteitType.drawing, // Use drawing as unified type
      content: jsonContent,
      imagePath: finalLocalPath,
      sender: 'you',
      syncStatus: SyncStatus.sending,
    );

    _notes.insert(0, newItem);
    await _persist();

    if (_coupleId != null && _userId != null) {
      await NoteitSyncManager.instance.enqueue(
        NoteitSyncTask(
          id: noteId,
          type: NoteitType.drawing,
          content: jsonContent,
          imagePath: finalLocalPath,
          createdAt: newItem.createdAt,
        ),
      );
    } else {
      updateItemSyncStatus(noteId, SyncStatus.failed);
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'created',
      title: 'Created canvas note 🎨',
      description: 'Shared an interactive canvas note',
      icon: '🎨',
      referenceId: noteId,
      route: 'doodle_notes',
    );
  }
```

- [ ] **Step 3: Commit**

Run:
```bash
git add lib/providers/noteit_provider.dart lib/services/noteit_sync_manager.dart
git commit -m "feat: add sendCanvas provider method and enable generic background sync"
```

---

### Task 3: Color Picker & Drawing Canvas with Flood Fill

**Files:**
- Create: [color_picker_dialog.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/widgets/color_picker_dialog.dart)
- Create: [raster_canvas.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/widgets/raster_canvas.dart)

**Interfaces:**
- Produces: `ColorPickerDialog` and `RasterCanvas` with queue-based flood fill.

- [ ] **Step 1: Implement ColorPickerDialog**

Create `lib/widgets/color_picker_dialog.dart` containing:
- Predefined grid of colors.
- HSV Hue and Saturation/Value sliders for selecting any custom color.

- [ ] **Step 2: Implement RasterCanvas with flood fill BFS**

Create `lib/widgets/raster_canvas.dart`:
- Fixed offscreen canvas size `600x600` pixels.
- On touch events, draws onto a `ui.Image` buffer.
- Paint Bucket tool checks tapped pixel and runs BFS flood-fill on the image's `Uint32List` buffer:
```dart
void _floodFill(Uint32List pixels, int width, int height, int startX, int startY, int targetColor, int replacementColor) {
  if (targetColor == replacementColor) return;
  final queue = <int>[];
  queue.add(startY * width + startX);
  
  while (queue.isNotEmpty) {
    final idx = queue.removeAt(0);
    if (pixels[idx] == targetColor) {
      pixels[idx] = replacementColor;
      final x = idx % width;
      final y = idx ~/ width;
      
      if (x > 0 && pixels[idx - 1] == targetColor) queue.add(idx - 1);
      if (x < width - 1 && pixels[idx + 1] == targetColor) queue.add(idx + 1);
      if (y > 0 && pixels[idx - width] == targetColor) queue.add(idx - width);
      if (y < height - 1 && pixels[idx + width] == targetColor) queue.add(idx + width);
    }
  }
}
```

- [ ] **Step 3: Commit**

Run:
```bash
git add lib/widgets/color_picker_dialog.dart lib/widgets/raster_canvas.dart
git commit -m "feat: add color picker dialog and raster canvas drawing with flood fill"
```

---

### Task 4: Rich Text Overlay & Overlay Gestures

**Files:**
- Create: [text_overlay_widget.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/widgets/text_overlay_widget.dart)
- Create: [rich_text_editor_overlay.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/widgets/rich_text_editor_overlay.dart)

**Interfaces:**
- Consumes: `CanvasTextOverlay` model.
- Produces: `TextOverlayWidget` with dynamic drag & scale gestures and `RichTextEditorOverlay` view.

- [ ] **Step 1: Implement RichTextEditorOverlay**

Create `lib/widgets/rich_text_editor_overlay.dart`:
- Semi-transparent blurred background.
- Large center text field with formatting options (bold, italic, alignment, background style, and color picker integration).

- [ ] **Step 2: Implement TextOverlayWidget**

Create `lib/widgets/text_overlay_widget.dart` wrapped with a `GestureDetector` that updates the overlays' x/y positions on drag, and updates scale/pinch factors on scale update.

- [ ] **Step 3: Commit**

Run:
```bash
git add lib/widgets/text_overlay_widget.dart lib/widgets/rich_text_editor_overlay.dart
git commit -m "feat: add movable rich text overlay and full-screen editor overlay"
```

---

### Task 5: Main Editor Assembly & History Rendering

**Files:**
- Modify: [noteit_screen.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/screens/together/noteit_screen.dart)

**Interfaces:**
- Consumes: Unified Canvas components.
- Produces: The fully integrated Square Canvas Editor page and Backward-compatible history card rendering.

- [ ] **Step 1: Implement history cards rendering fallback**

In `lib/screens/together/noteit_screen.dart`, update `_buildWidgetContent(item)` to render the canvas drawing layer + text overlays if the content is valid JSON; otherwise fallback to old painters.

- [ ] **Step 2: Unify editor into a single Square Canvas Editor view**

Modify `lib/screens/together/noteit_screen.dart` to combine all tabs (Doodle, Text, Photo) into a 2-tab view:
- **Canvas Editor** (contains the Stack canvas, custom toolbar with pens, bucket, text add, background controls).
- **History**

- [ ] **Step 3: Commit**

Run:
```bash
git add lib/screens/together/noteit_screen.dart
git commit -m "feat: assemble unified square canvas editor UI and history renderers"
```
