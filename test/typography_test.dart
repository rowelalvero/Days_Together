import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:days_together/themes/app_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('AppTypography returns correct styles and overrides', () {
    final titleStyle = AppTypography.pageTitle();
    expect(titleStyle, isNotNull);
    expect(titleStyle.fontSize, 28.0);
    expect(titleStyle.fontWeight, FontWeight.w700);

    final bodyStyle = AppTypography.bodyMedium(color: Colors.red, fontSize: 13.0);
    expect(bodyStyle.color, Colors.red);
    expect(bodyStyle.fontSize, 13.0);
  });
}
