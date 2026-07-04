# Unified Scrapbook Canvas Design Spec

We are unifying the doodle, text note, and photo features into a single, interactive, square canvas editor. This document outlines the technical architecture, data model, controls, interactions, and verification plan.

## Goal

Create a premium, Messenger-style interactive story/scrapbook editor where couples can:
- Select a background (either a custom solid color or a photo from gallery/camera).
- Sketch with various pen tools (Pen, Pencil, Marker, Eraser).
- Fill shapes or the canvas background using a Paint Bucket tool.
- Add and position multiple rich text overlays that support dragging and pinch-to-scale.
- Sync notes seamlessly between partners with offline queue support.

---

## 1. Data Model & Serialization

To support the rich canvas state while maintaining backward compatibility, the canvas details will be stored in `NoteitItem.content` as a JSON string.

### noteit_model.dart JSON Schema

```json
{
  "version": 1,
  "backgroundColor": 4279069466,
  "backgroundImage": "optional_local_or_remote_url",
  "drawingLayer": "data:image/png;base64,iVBORw0KGgo...",
  "textOverlays": [
    {
      "id": "uuid-string-1",
      "text": "Love you! ❤️",
      "x": 120.0,
      "y": 240.0,
      "scale": 1.2,
      "fontSize": 20.0,
      "color": 4294967295,
      "backgroundColor": 1426063360,
      "isBold": true,
      "isItalic": false,
      "isUnderline": false,
      "alignment": "center"
    }
  ]
}
```

*   `backgroundColor`: Signed 32-bit ARGB integer.
*   `backgroundImage`: Local file path (during editing/sending) or remote Supabase storage URL (after sync).
*   `drawingLayer`: Base64 encoded PNG representation of the drawings (strokes & flood fills).
*   `textOverlays`: List of movable rich text labels.

### Backward Compatibility
*   If `NoteitItem.content` is not a valid JSON string (legacy notes), the UI will fallback to the existing painters (e.g. `ScaleDrawingPainter` for old vector drawing strokes, or rendering text notes on solid backgrounds).

---

## 2. Interactive Canvas Architecture (UI Stack)

The canvas editor is a single unified `Stack` widget wrapped in a `LayoutBuilder` to handle responsive layout constraints.

```
+-------------------------------------------------+
|                  AppBar (Send)                  |
+-------------------------------------------------+
|                                                 |
|  [Stack]                                        |
|  +-------------------------------------------+  |
|  | Layer 1: Background Color or Photo        |  |
|  +-------------------------------------------+  |
|  | Layer 2: Drawing Paint & Gesture Area     |  |
|  +-------------------------------------------+  |
|  | Layer 3: Positioned Text Overlay Widgets  |  |
|  +-------------------------------------------+  |
|                                                 |
+-------------------------------------------------+
| Toolbar: Pens, Bucket, Colors, Add Text, Photo  |
+-------------------------------------------------+
```

### Layer 1: Background
*   Renders a container with `backgroundColor`.
*   If `backgroundImage` (local path or network URL) is set, renders it filled/cropped to fit the canvas.

### Layer 2: Drawing & Fills (Raster Painter)
*   Integrates a `CustomPaint` backed by a custom class `RasterCanvasController`.
*   Maintains a low-level `ui.Image` buffer (initially transparent) representing the drawing layer.
*   Handles gestures:
    *   **Pen/Pencil/Marker/Eraser**: On pan update, draws lines to the offscreen buffer using a standard `ui.PictureRecorder`.
    *   **Paint Bucket**: On tap, extracts pixel bytes from the offscreen buffer and executes a queue-based flood fill.

### Layer 3: Text Overlays
*   Maps `textOverlays` to `Positioned` widgets.
*   Wrapped in a `GestureDetector` that tracks dragging (`onPanUpdate`) and pinch scale (`onScaleUpdate`).
*   Double-tapping an overlay opens the full-screen Rich Text Editor.

---

## 3. Drawing Tools & Flood Fill

### Tool Profiles

| Tool | Color | Opacity | Default Width | Paint Style / Cap |
| :--- | :--- | :--- | :--- | :--- |
| **Pen** | Selected | `1.0` | `4.0` | Round cap & join |
| **Pencil** | Selected | `0.7` | `2.0` | Round cap & join (thin, organic) |
| **Marker** | Selected | `0.35` | `18.0` | Round cap & join (broad highlighter) |
| **Eraser** | None | `1.0` | `24.0` | `BlendMode.clear` |
| **Paint Bucket**| Selected | `1.0` | - | Flood fill algorithm / Canvas fill |

### Flood Fill Algorithm (BFS)

When the Bucket Tool is selected and the user taps at position `(x, y)` on the canvas:
1.  Map the local tap coordinate to the offscreen image coordinate space (e.g., `600x600`).
2.  If the pixel at `(x, y)` has a color of `0` (transparent), we trigger a **Canvas Fill** (update the overall background color of the canvas).
3.  Otherwise, we perform a raster **Flood Fill**:
    *   Extract the pixel bytes as a `Uint32List`.
    *   Start from `targetIndex = y * width + x`. Get the `targetColor`.
    *   Initialize a queue of indices and apply a breadth-first search to change adjacent pixels matching `targetColor` to the selected `replacementColor`.
    *   Repaint the updated pixel buffer back to the offscreen image.

---

## 4. Color Picker

The color section provides a list of beautiful palette colors. The last circle in the palette acts as an "+" button which launches a bottom sheet containing:
*   A grid of curated pastel and vibrant colors.
*   A Hue/Saturation color bar picker allowing selection of custom color coordinates.

---

## 5. Rich Text Editor Overlay

Tapping "Add Text" toggles the rich text editing mode:
1.  Shows a full-screen blurred backdrop filter.
2.  Provides a centered `TextField` with `autofocus` and rich styling states.
3.  Displays a style toolbar:
    *   **Contrast / Background Fill**: Cycles between plain text, solid colored box with contrasting text, and semi-transparent dark/light box.
    *   **Format**: Toggle buttons for Bold, Italic, Underline.
    *   **Alignment**: Left, Center, Right.
    *   **Font Size**: Slider or simple tap-to-adjust.
4.  Tapping "Done" serializes the text settings and creates a new overlay widget placed at the center of the canvas, which can then be dragged or resized.

---

## Verification Plan

### Automated Tests
*   **Model serialization tests**: Verify that the canvas data model converts to and from JSON correctly.
*   **Legacy fallback tests**: Verify that legacy drawing paths (old vector drawings) parse correctly without causing crashes.

### Manual Verification
*   **Drawing tools**: Draw with Pencil, Pen, and Marker to verify thickness and opacity.
*   **Eraser tool**: Erase drawings on top of a photo background. Verify that the photo remains untouched and only drawing strokes are removed.
*   **Paint Bucket**: Draw an enclosed circle. Fill the circle and verify that only the inside gets colored. Fill the empty canvas and verify the canvas background changes.
*   **Rich Text overlay**: Add a text overlay. Drag it, pinch-to-zoom to change its scale, double-tap it to edit, and check that formatting options (Bold, background color, alignments) reflect correctly.
*   **Sharing and sync**: Send a unified note to the partner. Check that it loads exactly as designed on the receiving screen.
