import 'package:flutter/material.dart';

/// App Shadows - Matches React shadow utilities
class AppShadows {
  AppShadows._();

  // Shadow levels matching Tailwind
  static BoxShadow get sm => BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 2,
        offset: const Offset(0, 1),
      );

  static BoxShadow get md => BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 4,
        offset: const Offset(0, 2),
      );

  static BoxShadow get lg => BoxShadow(
        color: Colors.black.withOpacity(0.15),
        blurRadius: 8,
        offset: const Offset(0, 4),
      );

  static BoxShadow get xl => BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 12,
        offset: const Offset(0, 6),
      );

  static BoxShadow get xxl => BoxShadow(
        color: Colors.black.withOpacity(0.25),
        blurRadius: 16,
        offset: const Offset(0, 8),
      );

  // Custom shadows from React screens
  static BoxShadow get card => BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 2),
      );

  static BoxShadow get cardHover => BoxShadow(
        color: Colors.black.withOpacity(0.15),
        blurRadius: 12,
        offset: const Offset(0, 4),
      );

  static BoxShadow get bottomNav => BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 20,
        offset: const Offset(0, -4),
      );

  // List of shadows for multiple shadow effects
  static List<BoxShadow> get cardShadows => [card];
  static List<BoxShadow> get cardHoverShadows => [cardHover];
  static List<BoxShadow> get bottomNavShadows => [bottomNav];
}


