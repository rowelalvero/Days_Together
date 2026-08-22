import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  /// Phase 7 of the architecture migration (design-system.md): replaces
  /// `mainCounter` and `pageTitle`, which were byte-for-byte identical
  /// (28pt, weight 700) -- one role, not two, per the design doc's own
  /// typography-consolidation table.
  static TextStyle display({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spectral(
      fontSize: fontSize ?? 28.0,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: height,
    );
  }

  /// Phase 7: renamed from `sectionHeader` (single source, defaults
  /// unchanged -- see design-system.md's typography-consolidation table).
  static TextStyle heading({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spectral(
      fontSize: fontSize ?? 20.0,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: height,
    );
  }

  /// Phase 7: renamed from `cardTitle` (single source, defaults unchanged --
  /// see design-system.md's typography-consolidation table).
  static TextStyle title({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spectral(
      fontSize: fontSize ?? 18.0,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: height,
    );
  }

  static TextStyle cardCategory({Color? color, double? fontSize, FontWeight? fontWeight, double? height, double? letterSpacing}) {
    return GoogleFonts.spectral(
      fontSize: fontSize ?? 8.5,
      fontWeight: fontWeight ?? FontWeight.w800,
      color: color,
      height: height,
      letterSpacing: letterSpacing ?? 0.5,
    );
  }

  static TextStyle body({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spectral(
      fontSize: fontSize ?? 14.0,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
    );
  }

  static TextStyle bodyLarge({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spectral(
      fontSize: fontSize ?? 14.0,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      height: height,
    );
  }

  static TextStyle bodyMedium({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spectral(
      fontSize: fontSize ?? 12.0,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
    );
  }

  /// Phase 7: fixed to use an actual monospace font (was silently
  /// rendering in Spectral, the serif body font) for its real call sites --
  /// PIN/code entry and hex color input. Size/weight defaults unchanged.
  static TextStyle bodyMono({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.robotoMono(
      fontSize: fontSize ?? 12.0,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
    );
  }

  static TextStyle button({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spectral(
      fontSize: fontSize ?? 10.5,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: height,
    );
  }

  static TextStyle caption({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spectral(
      fontSize: fontSize ?? 10.5,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
    );
  }

  /// Phase 7: fixed to use an actual monospace font (was silently
  /// rendering in Spectral) for its real call sites -- UID/CID debug text
  /// and stylized uppercase labels. Size/weight defaults unchanged.
  static TextStyle captionMono({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.robotoMono(
      fontSize: fontSize ?? 9.0,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      height: height,
    );
  }

  static TextStyle lora({Color? color, double? fontSize, FontWeight? fontWeight, double? height, FontStyle? fontStyle}) {
    return GoogleFonts.spectral(
      fontSize: fontSize ?? 14.0,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
      fontStyle: fontStyle,
    );
  }

  static TextStyle cormorant({Color? color, double? fontSize, FontWeight? fontWeight, double? height, FontStyle? fontStyle}) {
    return GoogleFonts.spectral(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      fontStyle: fontStyle,
    );
  }

  static TextStyle spectral({Color? color, double? fontSize, FontWeight? fontWeight, double? height, FontStyle? fontStyle}) {
    return GoogleFonts.spectral(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      fontStyle: fontStyle,
    );
  }
}
