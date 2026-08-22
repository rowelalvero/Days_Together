import 'package:flutter/widgets.dart' show Offset;

/// Serializes a hand-drawn signature (a list of strokes, each a list of
/// points) to and from the delimited string stored in `LicenseDetails`'s
/// `yourSignature`/`partnerSignature` fields. Extracted out of
/// relationship_license_screen.dart (Migration Phase 8) -- was two
/// top-level private functions (`_serializeSignature`/
/// `_deserializeSignature`) used across three of the file's classes with
/// no shared home.
///
/// Wire format: strokes joined by `|`, points within a stroke joined by
/// `;`, each point as `dx,dy` fixed to one decimal place.
class SignatureCodec {
  const SignatureCodec._();

  static String encode(List<List<Offset>> strokes) {
    return strokes
        .map((stroke) {
          return stroke
              .map((p) => '${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}')
              .join(';');
        })
        .join('|');
  }

  static List<List<Offset>> decode(String? data) {
    if (data == null || data.isEmpty) return [];

    try {
      return data.split('|').map((strokeStr) {
        if (strokeStr.isEmpty) return <Offset>[];

        return strokeStr.split(';').map((pointStr) {
          final parts = pointStr.split(',');
          return Offset(double.parse(parts[0]), double.parse(parts[1]));
        }).toList();
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
