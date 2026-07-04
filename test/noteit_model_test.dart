import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/models/noteit_model.dart';

void main() {
  group('CanvasData Model', () {
    test('fromJson and toJson roundtrip', () {
      final jsonStr = '{"version":1,"backgroundColor":4279069466,"drawingLayer":"base64data","textOverlays":[{"id":"1","text":"Love","x":100.0,"y":200.0,"scale":1.5,"fontSize":16.0,"color":4294967295,"backgroundColor":0,"isBold":true,"isItalic":false,"isUnderline":false,"alignment":"center"}]}';
      
      final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
      final canvasData = CanvasData.fromJson(jsonMap);
      
      expect(canvasData.version, 1);
      expect(canvasData.backgroundColor, 4279069466);
      expect(canvasData.drawingLayer, 'base64data');
      expect(canvasData.textOverlays.length, 1);
      
      final overlay = canvasData.textOverlays.first;
      expect(overlay.id, '1');
      expect(overlay.text, 'Love');
      expect(overlay.x, 100.0);
      expect(overlay.y, 200.0);
      expect(overlay.scale, 1.5);
      expect(overlay.fontSize, 16.0);
      expect(overlay.color, 4294967295);
      expect(overlay.backgroundColor, 0);
      expect(overlay.isBold, true);
      expect(overlay.isItalic, false);
      expect(overlay.isUnderline, false);
      expect(overlay.alignment, 'center');
      
      final roundtripJson = canvasData.toJson();
      expect(roundtripJson['backgroundColor'], 4279069466);
      expect(roundtripJson['textOverlays'][0]['text'], 'Love');
    });
  });
}
