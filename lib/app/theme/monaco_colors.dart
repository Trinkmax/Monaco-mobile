import 'package:flutter/material.dart';

/// Paleta de colores Monaco Smart Barber
/// Derivada del dashboard web (OKLCH → sRGB hex)
class MonacoColors {
  MonacoColors._();

  // Backgrounds
  static const Color background = Color(0xFF1A1A1A);
  static const Color surface = Color(0xFF242424);
  static const Color surfaceVariant = Color(0xFF2E2E2E);
  static const Color sidebar = Color(0xFF141414);

  // Foregrounds
  static const Color foreground = Color(0xFFF3F3F3);
  static const Color foregroundMuted = Color(0xFFA1A1A1);
  static const Color foregroundSubtle = Color(0xFF737373);

  // Primary (white-on-dark scheme)
  static const Color primary = Color(0xFFF3F3F3);
  static const Color primaryForeground = Color(0xFF1A1A1A);

  // Secondary
  static const Color secondary = Color(0xFF333333);
  static const Color secondaryForeground = Color(0xFFF3F3F3);

  // Accent
  static const Color accent = Color(0xFF333333);
  static const Color accentForeground = Color(0xFFF3F3F3);

  // Destructive
  static const Color destructive = Color(0xFFE5484D);
  static const Color destructiveForeground = Color(0xFFF3F3F3);

  // Borders & Input
  static const Color border = Color(0x1FFFFFFF); // white 12%
  static const Color borderStrong = Color(0x33FFFFFF); // white 20%
  static const Color input = Color(0x26FFFFFF); // white 15%

  // Status
  static const Color success = Color(0xFF30A46C);
  static const Color warning = Color(0xFFF5A623);
  static const Color info = Color(0xFF0091FF);

  // Occupancy indicators
  static const Color occupancyLow = Color(0xFF30A46C);     // verde
  static const Color occupancyMedium = Color(0xFFF5A623);   // amarillo
  static const Color occupancyHigh = Color(0xFFE5484D);     // rojo

  // Charts (5 levels grayscale like web)
  static const Color chart1 = Color(0xFFF3F3F3);
  static const Color chart2 = Color(0xFFBBBBBB);
  static const Color chart3 = Color(0xFF888888);
  static const Color chart4 = Color(0xFF555555);
  static const Color chart5 = Color(0xFF333333);

  // Card gradient overlay
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A2A2A), Color(0xFF1E1E1E)],
  );

  // Accent (Monaco branding — white on dark)
  static const Color gold = Color(0xFFF3F3F3);
  static const Color goldLight = Color(0xFFFFFFFF);

  // Review stars
  static const Color starFilled = Color(0xFFF5A623);
  static const Color starEmpty = Color(0xFF444444);

  // Aliases for convenience
  static const Color textPrimary = foreground;
  static const Color textSecondary = foregroundMuted;
  static const Color textSubtle = foregroundSubtle;
  static const Color divider = border;
}
