import 'package:flutter/material.dart';

/// Paleta de colores barberOS
/// Estética: negro puro, blanco puro — minimal tech
class MonacoColors {
  MonacoColors._();

  // Backgrounds
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceVariant = Color(0xFF1A1A1A);
  static const Color sidebar = Color(0xFF050505);

  // Foregrounds
  static const Color foreground = Color(0xFFFFFFFF);
  static const Color foregroundMuted = Color(0xFFA3A3A3);
  static const Color foregroundSubtle = Color(0xFF6B6B6B);

  // Primary (blanco puro sobre negro — identidad barberOS)
  static const Color primary = Color(0xFFFFFFFF);
  static const Color primaryForeground = Color(0xFF000000);

  // Secondary
  static const Color secondary = Color(0xFF1C1C1C);
  static const Color secondaryForeground = Color(0xFFFFFFFF);

  // Accent
  static const Color accent = Color(0xFF1C1C1C);
  static const Color accentForeground = Color(0xFFFFFFFF);

  // Destructive
  static const Color destructive = Color(0xFFE5484D);
  static const Color destructiveForeground = Color(0xFFFFFFFF);

  // Borders & Input
  static const Color border = Color(0x26FFFFFF); // white 15%
  static const Color borderStrong = Color(0x40FFFFFF); // white 25%
  static const Color input = Color(0x1AFFFFFF); // white 10%

  // Status
  static const Color success = Color(0xFF30A46C);
  static const Color warning = Color(0xFFF5A623);
  static const Color info = Color(0xFF0091FF);

  // Occupancy indicators
  static const Color occupancyLow = Color(0xFF30A46C);     // verde
  static const Color occupancyMedium = Color(0xFFF5A623);   // amarillo
  static const Color occupancyHigh = Color(0xFFE5484D);     // rojo

  // Charts (5 levels grayscale)
  static const Color chart1 = Color(0xFFFFFFFF);
  static const Color chart2 = Color(0xFFBBBBBB);
  static const Color chart3 = Color(0xFF888888);
  static const Color chart4 = Color(0xFF444444);
  static const Color chart5 = Color(0xFF222222);

  // Card gradient overlay
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF181818), Color(0xFF0D0D0D)],
  );

  // Accent (barberOS — blanco puro sobre negro profundo)
  static const Color gold = Color(0xFFFFFFFF);
  static const Color goldLight = Color(0xFFFFFFFF);

  // ── Monaco brand (Liquid Glass iOS 26) ────────────────────────────────────
  /// Verde Monaco — acento principal del lenguaje visual liquid glass.
  static const Color monacoGreen = Color(0xFF22C55E);

  /// Verde Monaco más profundo — para gradients y estados "activos".
  static const Color monacoGreenDeep = Color(0xFF16A34A);

  /// Azul profundo — orbe secundario del backdrop animado.
  static const Color deepBlue = Color(0xFF1E3A8A);

  /// Violeta — orbe terciario del backdrop animado.
  static const Color deepViolet = Color(0xFF7C3AED);

  // Review stars
  static const Color starFilled = Color(0xFFF5A623);
  static const Color starEmpty = Color(0xFF444444);

  // Aliases for convenience
  static const Color textPrimary = foreground;
  static const Color textSecondary = foregroundMuted;
  static const Color textSubtle = foregroundSubtle;
  static const Color divider = border;
}
