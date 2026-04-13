import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App Text Styles - Using Cairo font (Arabic)
/// Matches React font configuration
class AppTextStyles {
  AppTextStyles._();

  // Cairo font family - matches React: "Cairo", "Cairo Fallback", sans-serif
  static TextStyle _base({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.cairo(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Headings
  static TextStyle h1({Color? color}) => _base(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: color,
      );

  static TextStyle h2({Color? color}) => _base(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: color,
      );

  static TextStyle h3({Color? color}) => _base(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: color,
      );

  static TextStyle h4({Color? color}) => _base(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: color,
      );

  // Body text
  static TextStyle bodyLarge({Color? color}) => _base(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle bodyMedium({Color? color}) => _base(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle bodySmall({Color? color}) => _base(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // Labels
  static TextStyle labelLarge({Color? color}) => _base(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle labelMedium({Color? color}) => _base(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle labelSmall({Color? color}) => _base(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: color,
      );

  // Buttons
  static TextStyle buttonLarge({Color? color}) => _base(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: color,
      );

  static TextStyle buttonMedium({Color? color}) => _base(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle buttonSmall({Color? color}) => _base(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      );
}


