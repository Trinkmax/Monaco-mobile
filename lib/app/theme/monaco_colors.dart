import 'package:flutter/material.dart';

/// Paleta de la app de Monaco Barber Studio.
/// Estética: negro profundo + vidrio líquido + acento verde Monaco.
class MonacoColors {
  MonacoColors._();

  // Backgrounds
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceVariant = Color(0xFF1A1A1A);

  // Foregrounds
  static const Color foreground = Color(0xFFFFFFFF);
  static const Color foregroundMuted = Color(0xFFA3A3A3);
  static const Color foregroundSubtle = Color(0xFF6B6B6B);

  // Primary (blanco sobre negro)
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
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Occupancy indicators (una sola paleta para toda la app)
  static const Color occupancyNone = Color(0xFF22C55E); // sin espera
  static const Color occupancyLow = Color(0xFF84CC16); // espera corta
  static const Color occupancyMedium = Color(0xFFF59E0B); // movimiento
  static const Color occupancyHigh = Color(0xFFEF4444); // alta demanda
  static const Color occupancyClosed = Color(0xFF6B6B6B);

  // ── Marca Monaco ──────────────────────────────────────────────────────────
  /// Verde Monaco — acento principal del lenguaje visual liquid glass.
  static const Color monacoGreen = Color(0xFF22C55E);

  /// Verde Monaco más profundo — para gradients y estados "activos".
  static const Color monacoGreenDeep = Color(0xFF16A34A);

  /// Acento de **estado de interfaz**: chip seleccionado, día elegido, paso
  /// actual, CTA principal.
  ///
  /// Es blanco a propósito (decisión del dueño, 27/ago/2026). El verde de marca
  /// quedó reservado para lo que significa algo del negocio —"sin espera" en la
  /// fila, el velo de turno confirmado, los toasts de éxito—: cuando además
  /// teñía cada chip, cada día y cada botón, esas dos cosas se confundían y el
  /// wizard entero se leía verde. Sobre vidrio oscuro, lo claro ya comunica
  /// "elegido" sin gastar color.
  static const Color seleccion = Color(0xFFFFFFFF);

  /// Rojo de los corchetes del logotipo [ BARBER STUDIO ]. Sólo para detalles
  /// de marca (no para estados: para eso está `destructive`).
  static const Color brandRed = Color(0xFFE30613);

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

  /// Alias histórico (era "gold" en la versión barberOS y siempre fue blanco).
  /// Queda sólo para las pantallas que todavía no migraron a Liquid Glass.
  @Deprecated('Usar MonacoColors.primary / monacoGreen según el caso')
  static const Color gold = Color(0xFFFFFFFF);
}
