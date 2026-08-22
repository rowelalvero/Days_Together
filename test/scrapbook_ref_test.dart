import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/core/scrapbook_ref.dart';

void main() {
  group('ScrapbookRef', () {
    test('round-trips through toChatPayload/fromChatPayload', () {
      const ref = ScrapbookRef('abc-123');
      final parsed = ScrapbookRef.fromChatPayload(ref.toChatPayload());
      expect(parsed, ref);
    });

    test('toChatPayload uses the current, non-legacy wire prefix', () {
      const ref = ScrapbookRef('abc-123');
      expect(ref.toChatPayload(), 'scrapbook:abc-123');
    });

    test('fromChatPayload still recognizes the legacy [scrapbook]: prefix', () {
      // Already-sent production love_chat messages used this prefix before
      // ScrapbookRef existed -- they must keep rendering correctly.
      final parsed = ScrapbookRef.fromChatPayload('[scrapbook]:legacy-id');
      expect(parsed, const ScrapbookRef('legacy-id'));
    });

    test('fromChatPayload returns null for an unrelated chat message', () {
      expect(ScrapbookRef.fromChatPayload('Hey, how are you?'), isNull);
    });

    test('fromChatPayload returns null for a prefix with no id', () {
      expect(ScrapbookRef.fromChatPayload('scrapbook:'), isNull);
      expect(ScrapbookRef.fromChatPayload('[scrapbook]:'), isNull);
    });

    test('equality is based on itemId', () {
      expect(const ScrapbookRef('x'), const ScrapbookRef('x'));
      expect(const ScrapbookRef('x') == const ScrapbookRef('y'), isFalse);
    });
  });
}
