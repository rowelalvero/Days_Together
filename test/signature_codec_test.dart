import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/features/relationship/data/signature_codec.dart';

void main() {
  group('SignatureCodec', () {
    test('round-trips a multi-stroke signature (values already at 1 decimal place)', () {
      final strokes = [
        [const Offset(1.0, 2.0), const Offset(3.5, 4.5)],
        [const Offset(10.1, 20.2)],
      ];

      final encoded = SignatureCodec.encode(strokes);
      final decoded = SignatureCodec.decode(encoded);

      expect(decoded, strokes);
    });

    test('encode rounds each coordinate to one decimal place', () {
      final strokes = [
        [const Offset(1.23456, 2.98765)],
      ];

      expect(SignatureCodec.encode(strokes), '1.2,3.0');
    });

    test('decode returns an empty list for null or empty input', () {
      expect(SignatureCodec.decode(null), isEmpty);
      expect(SignatureCodec.decode(''), isEmpty);
    });

    test('decode returns an empty list for malformed input instead of throwing', () {
      expect(SignatureCodec.decode('not,valid;data|here'), isEmpty);
    });

    test('encode of an empty stroke list produces an empty string', () {
      expect(SignatureCodec.encode([]), '');
    });
  });
}
