import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:days_together/app/theme/app_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('AppTypography returns correct styles and overrides', () async {
    // Every style below starts a fire-and-forget font load, which fails in
    // tests: the font files are not bundled and runtime fetching is off.
    // Nothing awaits those loads, so the error went to the zone's
    // uncaught-error handler -- and surfaced inside whichever test happened
    // to be running ("failed after it had already completed"), an
    // intermittent red build. Absorb exactly that error here; anything else,
    // failed expectations included, still fails the test.
    final unexpected = <Object>[];
    await runZonedGuarded(
      () async {
        final titleStyle = AppTypography.display();
        expect(titleStyle, isNotNull);
        expect(titleStyle.fontSize, 28.0);
        expect(titleStyle.fontWeight, FontWeight.w700);

        final bodyStyle = AppTypography.bodyMedium(
          color: Colors.red,
          fontSize: 13.0,
        );
        expect(bodyStyle.color, Colors.red);
        expect(bodyStyle.fontSize, 13.0);

        final standardBodyStyle = AppTypography.body(
          color: Colors.green,
          fontSize: 15.0,
        );
        expect(standardBodyStyle.color, Colors.green);
        expect(standardBodyStyle.fontSize, 15.0);

        final cormorantStyle = AppTypography.cormorant(
          fontSize: 32,
          fontStyle: FontStyle.italic,
        );
        expect(cormorantStyle.fontFamily, contains('Spectral'));
        expect(cormorantStyle.fontSize, 32);
        expect(cormorantStyle.fontStyle, FontStyle.italic);

        final spectralStyle = AppTypography.spectral(
          fontSize: 18,
          color: Colors.blue,
        );
        expect(spectralStyle.fontFamily, contains('Spectral'));
        expect(spectralStyle.fontSize, 18);
        expect(spectralStyle.color, Colors.blue);

        // Let those loads finish inside this zone, not during a later test.
        try {
          await GoogleFonts.pendingFonts();
        } catch (_) {}
      },
      (error, _) {
        if (!error.toString().contains(
          'was not found in the application assets',
        )) {
          unexpected.add(error);
        }
      },
    );
    expect(unexpected, isEmpty);
  });
}
