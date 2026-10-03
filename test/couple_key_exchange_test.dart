import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/core/session/couple_key_exchange.dart';

void main() {
  test(
    'uses the current couple key when an old relationship row comes first',
    () {
      final rows = <Map<String, dynamic>>[
        {'couple_id': 'former-couple', 'wrapped_key': 'old-key'},
        {'couple_id': 'current-couple', 'wrapped_key': 'current-key'},
      ];

      expect(
        CoupleKeyExchange.wrappedKeyForCouple(rows, 'current-couple'),
        'current-key',
      );
      expect(
        CoupleKeyExchange.wrappedKeyForCouple(rows, 'other-couple'),
        isNull,
      );
    },
  );
}
