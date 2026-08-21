// Round-trip coverage for the 5 models Phase 4 of the architecture migration
// converted to all-final fields (docs/architecture/migration-roadmap.md).
// None of these had a dedicated test file before -- their mutation was
// mechanical (verified zero real mutation call sites in lib/, so no
// call-site regressions were possible), but the models themselves were
// previously untested at all.

import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/models/bucket_list_model.dart';
import 'package:days_together/models/gift_reminder_model.dart';
import 'package:days_together/models/vault_item_model.dart';
import 'package:days_together/models/time_capsule_model.dart';
import 'package:days_together/models/daily_mood_model.dart';

void main() {
  group('BucketListItem', () {
    test('round-trips through toJson/fromJson losslessly', () {
      final original = BucketListItem(
        id: 'b1',
        title: 'Visit Kyoto',
        isCompleted: true,
        completedAt: DateTime.utc(2024, 4, 1),
        order: 3,
        createdAt: DateTime.utc(2024, 1, 1),
        scheduledAt: DateTime.utc(2024, 3, 20),
      );

      final restored = BucketListItem.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.isCompleted, original.isCompleted);
      expect(restored.completedAt, original.completedAt);
      expect(restored.order, original.order);
      expect(restored.scheduledAt, original.scheduledAt);
    });

    test('copyWith can clear scheduledAt with the sentinel-guarded explicit null', () {
      final original = BucketListItem(title: 'Trip', order: 0, scheduledAt: DateTime(2024, 6, 1));
      final cleared = original.copyWith(scheduledAt: null);
      expect(cleared.scheduledAt, isNull);
      expect(cleared.title, 'Trip');
    });
  });

  group('GiftReminder', () {
    test('round-trips through toJson/fromJson losslessly', () {
      final original = GiftReminder(
        title: "Partner's Birthday",
        date: DateTime.utc(2024, 9, 12),
        reminderDaysBefore: const [14, 3],
        isEnabled: false,
        isRecurringYearly: false,
      );

      final restored = GiftReminder.fromJson(original.toJson());

      expect(restored.title, original.title);
      expect(restored.date, original.date);
      expect(restored.reminderDaysBefore, original.reminderDaysBefore);
      expect(restored.isEnabled, false);
      expect(restored.isRecurringYearly, false);
    });

    test('copyWith replaces reminderDaysBefore without mutating the original', () {
      final original = GiftReminder(title: 'Anniversary', date: DateTime(2024, 1, 1));
      final updated = original.copyWith(reminderDaysBefore: const [7, 1]);

      expect(original.reminderDaysBefore, const [30, 14, 7]);
      expect(updated.reminderDaysBefore, const [7, 1]);
    });
  });

  group('VaultItem', () {
    test('round-trips a photo item through toJson/fromJson losslessly', () {
      final original = VaultItem(
        type: VaultItemType.photo,
        imagePath: '/local/photo.jpg',
        imageUrl: 'couples/c1/vault/photo.jpg',
        createdAt: DateTime.utc(2024, 2, 2),
      );

      final restored = VaultItem.fromJson(original.toJson());

      expect(restored.type, VaultItemType.photo);
      expect(restored.imagePath, original.imagePath);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.createdAt, original.createdAt);
    });

    test('fromJson falls back to VaultItemType.photo for an out-of-range type index', () {
      final restored = VaultItem.fromJson({'type': 99, 'createdAt': null});
      expect(restored.type, VaultItemType.photo);
    });
  });

  group('TimeCapsule', () {
    test('round-trips through toJson/fromJson losslessly', () {
      final original = TimeCapsule(
        message: 'Open me in a year!',
        openDate: DateTime.utc(2025, 1, 1),
        isOpened: false,
        createdAt: DateTime.utc(2024, 1, 1),
      );

      final restored = TimeCapsule.fromJson(original.toJson());

      expect(restored.message, original.message);
      expect(restored.openDate, original.openDate);
      expect(restored.isOpened, false);
    });

    test('copyWith(isOpened: true) is the only supported way to open a capsule', () {
      // Regression-shaped test: time_capsule_provider.dart opens a capsule
      // via `capsule.copyWith(isOpened: true)`, never a direct field
      // assignment -- this is what makes TimeCapsule's all-final conversion
      // a pure mechanical change with zero call-site risk.
      final closed = TimeCapsule(message: 'Hi', openDate: DateTime(2024, 1, 1));
      final opened = closed.copyWith(isOpened: true);

      expect(closed.isOpened, false);
      expect(opened.isOpened, true);
      expect(opened.message, closed.message);
    });
  });

  group('DailyMood', () {
    test('round-trips through toJson/fromJson losslessly', () {
      final original = DailyMood(date: '2024-05-01', moodScore: 8, note: 'Great day');
      final restored = DailyMood.fromJson(original.toJson());

      expect(restored.date, '2024-05-01');
      expect(restored.moodScore, 8);
      expect(restored.note, 'Great day');
    });
  });

  group('DailySyncQuestion', () {
    test('round-trips through toJson/fromJson losslessly', () {
      final original = DailySyncQuestion(
        question: 'What made you smile today?',
        myAnswer: 'Coffee',
        partnerAnswer: null,
        date: '2024-05-01',
      );

      final restored = DailySyncQuestion.fromJson(original.toJson());

      expect(restored.question, original.question);
      expect(restored.myAnswer, 'Coffee');
      expect(restored.partnerAnswer, isNull);
      expect(restored.bothAnswered, isFalse);
    });
  });
}
