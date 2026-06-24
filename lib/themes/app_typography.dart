import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextStyle pageTitle({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize ?? 28.0,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: height,
    );
  }

  static TextStyle sectionHeader({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize ?? 20.0,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: height,
    );
  }

  static TextStyle cardTitle({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize ?? 18.0,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: height,
    );
  }

  static TextStyle cardCategory({Color? color, double? fontSize, FontWeight? fontWeight, double? height, double? letterSpacing}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize ?? 8.5,
      fontWeight: fontWeight ?? FontWeight.w800,
      color: color,
      height: height,
      letterSpacing: letterSpacing ?? 0.5,
    );
  }

  static TextStyle bodyLarge({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.inter(
      fontSize: fontSize ?? 14.0,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      height: height,
    );
  }

  static TextStyle bodyMedium({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.inter(
      fontSize: fontSize ?? 12.0,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
    );
  }

  static TextStyle bodyMono({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize ?? 12.0,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
    );
  }

  static TextStyle button({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize ?? 10.5,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: height,
    );
  }

  static TextStyle caption({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.inter(
      fontSize: fontSize ?? 10.5,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
    );
  }

  static TextStyle captionMono({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize ?? 9.0,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      height: height,
    );
  }

  static TextStyle lora({Color? color, double? fontSize, FontWeight? fontWeight, double? height, FontStyle? fontStyle}) {
    return GoogleFonts.lora(
      fontSize: fontSize ?? 14.0,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
      fontStyle: fontStyle,
    );
  }
}
