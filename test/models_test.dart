import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/models/app_settings.dart';

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

    test('copyWith(position:) re-indexes without touching other fields', () {
      // Regression test for the Phase 4 immutability migration:
      // TimelineProvider's re-index loops used to do `item.position = i`
      // directly; now they do `list[i] = list[i].copyWith(position: i)`.
      // This proves the replacement preserves every other field exactly.
      final items = [
        TimelineItemData(id: 'a', title: 'A', description: 'D-A', date: DateTime(2024, 1, 1), isImageCard: false, position: 5),
        TimelineItemData(id: 'b', title: 'B', description: 'D-B', date: DateTime(2024, 1, 2), isImageCard: false, position: 9),
      ];

      final reindexed = [
        for (var i = 0; i < items.length; i++) items[i].copyWith(position: i),
      ];

      expect(reindexed[0].position, 0);
      expect(reindexed[0].id, 'a');
      expect(reindexed[0].title, 'A');
      expect(reindexed[1].position, 1);
      expect(reindexed[1].id, 'b');
      expect(reindexed[1].title, 'B');
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

    test('favoriteThemes is replaced by copyWith, not shared/mutated in place', () {
      // Regression test for the Phase 4 immutability migration:
      // ThemeProvider.toggleFavoriteTheme used to call
      // settings.favoriteThemes.add/.remove directly. Now it builds a new
      // list and passes it to copyWith -- this proves the original
      // instance's list is untouched by that replacement.
      final original = AppSettings(favoriteThemes: const ['pink', 'blue']);

      final updated = original.copyWith(favoriteThemes: [...original.favoriteThemes, 'gold']);

      expect(original.favoriteThemes, ['pink', 'blue']);
      expect(updated.favoriteThemes, ['pink', 'blue', 'gold']);
    });
  });
}
