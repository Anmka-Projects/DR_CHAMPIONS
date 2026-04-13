import 'package:flutter/material.dart';

/// App Border Radius - Matches CSS --radius variable
/// Source: --radius: 1.5rem (24px)
class AppRadius {
  AppRadius._();

  // Base radius: 1.5rem = 24px
  static const double base = 24.0;

  // Radius variants from CSS
  // --radius-sm: calc(var(--radius) - 4px) = 20px
  static const double sm = 20.0;

  // --radius-md: calc(var(--radius) - 2px) = 22px
  static const double md = 22.0;

  // --radius-lg: var(--radius) = 24px
  static const double lg = 24.0;

  // --radius-xl: calc(var(--radius) + 4px) = 28px
  static const double xl = 28.0;

  // Common radius values from React screens
  static const double card = 24.0; // rounded-3xl (24px)
  static const double button = 16.0; // rounded-2xl (16px)
  static const double input = 12.0; // rounded-xl (12px)
  static const double chip = 999.0; // rounded-full
  static const double smallCard = 16.0; // rounded-2xl
  static const double largeCard = 48.0; // rounded-[3rem] (48px)

  // BorderRadius objects for direct use
  static BorderRadius get cardBorderRadius => BorderRadius.circular(card);
  static BorderRadius get buttonBorderRadius => BorderRadius.circular(button);
  static BorderRadius get inputBorderRadius => BorderRadius.circular(input);
  static BorderRadius get chipBorderRadius => BorderRadius.circular(chip);
  static BorderRadius get smallCardBorderRadius => BorderRadius.circular(smallCard);
  static BorderRadius get largeCardBorderRadius => BorderRadius.circular(largeCard);
}


