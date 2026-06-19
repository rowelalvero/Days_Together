import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/models/timeline_model.dart';

void main() {
  group('TimelineItemData', () {
    test('fromJson tolerates missing optional fields', () {
      final item = TimelineItemData.fromJson(<String, dynamic>{
        'id': 'abc',
        'title': 'Hello',
        'description': 'World',
        'date': DateTime.now().toIso8601String(),
      });
      expect(item.id, 'abc');
      expect(item.isImageCard, false);
      expect(item.position, 0);
    });

    test('copyWith preserves untouched fields and supports clearing them', () {
      final original = TimelineItemData(
        id: 'x',
        title: 'T',
        description: 'D',
        imagePath: '/tmp/a.jpg',
        networkImageUrl: 'https://example.com/a.png',
        date: DateTime(2024, 1, 1),
        isImageCard: true,
        position: 0,
      );

      // Pass nothing for nullable fields — they must be preserved.
      final kept = original.copyWith(title: 'T2');
      expect(kept.imagePath, '/tmp/a.jpg');
      expect(kept.networkImageUrl, 'https://example.com/a.png');

      // Pass null explicitly — the field must be cleared.
      final cleared = original.copyWith(imagePath: null);
      expect(cleared.imagePath, isNull);
      expect(cleared.networkImageUrl, 'https://example.com/a.png');
    });
  });

  group('AppSettings', () {
    test('fromJson clamps a bad theme index back to midnightRose', () {
      final settings = AppSettings.fromJson(<String, dynamic>{
        'currentTheme': 999,
        'backgroundMusicEnabled': true,
        'musicVolume': 0.42,
        'selectedMusicPath': '/tmp/song.mp3',
        'favoriteThemes': <String>['pink', 'blue'],
      });
      expect(settings.currentTheme, ThemeType.midnightRose);
      expect(settings.musicVolume, closeTo(0.42, 1e-9));
    });

    test('copyWith can clear selectedMusicPath with explicit null', () {
      final original = AppSettings(selectedMusicPath: '/tmp/a.mp3');
      final cleared = original.copyWith(selectedMusicPath: null);
      expect(cleared.selectedMusicPath, isNull);
    });
  });
}
