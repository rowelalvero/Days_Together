import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/models/canvas_document.dart';

void main() {
  test('CanvasDocument Model serialization and deserialization roundtrip', () {
    final doc = CanvasDocument(
      version: 2,
      background: const BackgroundData(
        type: 'grid',
        color: 0xFFFFFFFF,
        step: 30.0,
      ),
      objects: [
        const StrokeObject(
          id: 's1',
          x: 10,
          y: 20,
          points: [CanvasPoint(0, 0), CanvasPoint(50, 100)],
          strokeWidth: 4.5,
          color: 0xFFFF0000,
          isEraser: false,
        ),
        const TextObject(
          id: 't1',
          x: 150,
          y: 120,
          text: 'Hello World',
          color: 0xFF00FF00,
          fontSize: 24,
          isBold: true,
        ),
        const ImageObject(
          id: 'i1',
          x: 200,
          y: 200,
          imagePath: '/local/cache/path.jpg',
          imageUrl: 'https://supabase.com/image.jpg',
        ),
        const ShapeObject(
          id: 'sh1',
          x: 300,
          y: 300,
          shapeType: 'rectangle',
          width: 100,
          height: 80,
          color: 0xFF0000FF,
          strokeWidth: 3,
          isFilled: true,
        ),
      ],
    );

    final jsonString = jsonEncode(doc.toJson());
    final decoded = CanvasDocument.fromJson(jsonDecode(jsonString));

    expect(decoded.version, doc.version);
    expect(decoded.background.type, doc.background.type);
    expect(decoded.background.color, doc.background.color);
    expect(decoded.background.step, doc.background.step);

    expect(decoded.objects.length, 4);

    final s = decoded.objects[0] as StrokeObject;
    expect(s.id, 's1');
    expect(s.points.length, 2);
    expect(s.points[0].x, 0.0);
    expect(s.points[1].y, 100.0);
    expect(s.color, 0xFFFF0000);
    expect(s.isEraser, false);

    final t = decoded.objects[1] as TextObject;
    expect(t.text, 'Hello World');
    expect(t.isBold, true);
    expect(t.isItalic, false);

    final img = decoded.objects[2] as ImageObject;
    expect(img.imagePath, '/local/cache/path.jpg');
    expect(img.imageUrl, 'https://supabase.com/image.jpg');

    final sh = decoded.objects[3] as ShapeObject;
    expect(sh.shapeType, 'rectangle');
    expect(sh.isFilled, true);
  });
}
