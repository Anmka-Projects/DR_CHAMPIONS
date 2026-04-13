/// App Spacing - Matches Tailwind spacing scale
/// Used for consistent spacing throughout the app
class AppSpacing {
  AppSpacing._();

  // Base spacing unit (4px in Tailwind)
  static const double base = 4.0;

  // Standard spacing values
  static const double xs = 4.0; // 1 unit
  static const double sm = 8.0; // 2 units
  static const double md = 12.0; // 3 units
  static const double lg = 16.0; // 4 units
  static const double xl = 20.0; // 5 units
  static const double xxl = 24.0; // 6 units
  static const double xxxl = 32.0; // 8 units
  static const double xxxxl = 40.0; // 10 units
  static const double xxxxxl = 48.0; // 12 units
  static const double xxxxxxl = 64.0; // 16 units

  // Common spacing patterns from React screens
  static const double screenPadding = 16.0; // px-4
  static const double cardPadding = 16.0; // p-4
  static const double sectionSpacing = 24.0; // mb-6
  static const double itemSpacing = 12.0; // gap-3
  static const double largeItemSpacing = 16.0; // gap-4
}


