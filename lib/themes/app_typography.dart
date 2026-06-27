import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextStyle mainCounter({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spectral(
      fontSize: fontSize ?? 28.0,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: height,
    );
  }

  static TextStyle pageTitle({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spectral(
      fontSize: fontSize ?? 28.0,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: height,
    );
  }

  static TextStyle sectionHeader({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spectral(
      fontSize: fontSize ?? 20.0,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      height: height,
    );
  }

  static TextStyle cardTitle({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
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

  static TextStyle bodyMono({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    // Keep mono style but using Spectral for consistency as requested if possible, 
    // but Spectral is not a mono font. 
    // Usually "bodyMono" implies a technical/code style.
    // However, the prompt says "Replace the current default font with Spectral across the entire application."
    // I will use Spectral but keep the size/weight.
    return GoogleFonts.spectral(
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

  static TextStyle captionMono({Color? color, double? fontSize, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.spectral(
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
