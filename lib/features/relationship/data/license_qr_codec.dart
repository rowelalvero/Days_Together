import 'package:intl/intl.dart';

/// Builds the human-readable text banner encoded into the relationship
/// license's back-of-card QR code. Extracted out of `_LicenseBack`'s
/// `_buildQrData()` (Migration Phase 8) verbatim -- same output for the
/// same inputs, just callable and testable without a widget.
///
/// This is a one-way encoding, not a serialization format: the banner is
/// decorative prose meant for a human who scans the code (uppercase
/// transforms, an em-dash fallback for an unset gender, blank separator
/// lines), not a delimited key-value format designed to be parsed back.
/// There is no QR-scanning/import feature anywhere in this app today, so a
/// `decode()` counterpart would be speculative code with no real caller --
/// see migration-roadmap.md's Phase 8 notes for why this deliberately
/// diverges from `god-file-decomposition.md`'s original `encode`/`decode`
/// sketch.
class LicenseQrCodec {
  const LicenseQrCodec._();

  static String encode({
    required String holderName,
    required String? holderGender,
    required DateTime? holderBirthdate,
    required String? holderAddress,
    required String holderNationality,
    required String holderWeight,
    required String holderHeight,
    required String holderBloodType,
    required String holderEyeColor,
    required String holderConditions,
    required DateTime? holderDateIssued,
    required String emergencyName,
    required String emergencyPhone,
    required DateTime? startDate,
  }) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    final startDateStr = startDate != null ? dateFormat.format(startDate) : 'Not set';

    final birthdateStr = holderBirthdate != null ? dateFormat.format(holderBirthdate) : 'Not set';

    final issuedDateStr = holderDateIssued != null
        ? dateFormat.format(holderDateIssued)
        : (startDate != null ? dateFormat.format(startDate) : 'Not set');

    final buf = StringBuffer();

    buf.writeln('═══ RELATIONSHIP LICENSE ═══');
    buf.writeln('HOLDER: ${holderName.toUpperCase()}');
    buf.writeln('SEX: ${(holderGender ?? "—").toUpperCase()}');
    buf.writeln('BIRTHDATE: $birthdateStr');
    buf.writeln('NATIONALITY: ${holderNationality.toUpperCase()}');
    buf.writeln('WEIGHT: ${holderWeight.toUpperCase()}');
    buf.writeln('HEIGHT: ${holderHeight.toUpperCase()}');
    buf.writeln('ADDRESS: ${holderAddress ?? "Not set"}');
    buf.writeln('');
    buf.writeln('EMERGENCY CONTACT (PARTNER):');
    buf.writeln('Name: ${emergencyName.toUpperCase()}');
    buf.writeln('Phone: $emergencyPhone');
    buf.writeln('');
    buf.writeln('BLOOD TYPE: ${holderBloodType.toUpperCase()}');
    buf.writeln('EYES COLOR: ${holderEyeColor.toUpperCase()}');
    buf.writeln('CONDITIONS: ${holderConditions.toUpperCase()}');
    buf.writeln('');
    buf.writeln('TOGETHER SINCE: $startDateStr');
    buf.writeln('DATE ISSUED: $issuedDateStr');
    buf.writeln('STATUS: VALID FOREVER');

    return buf.toString();
  }
}
