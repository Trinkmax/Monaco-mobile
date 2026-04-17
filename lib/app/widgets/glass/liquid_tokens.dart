import 'package:flutter/material.dart';

/// Tokens del lenguaje visual "Liquid Glass" (iOS 26).
///
/// Centraliza radios, blur, duraciones, colores de borde direccional y
/// sombras para que todas las superficies sientan que están hechas del
/// mismo material.
class LiquidTokens {
  LiquidTokens._();

  // ── Marca ──────────────────────────────────────────────────────────────
  static const Color monacoGreen = Color(0xFF22C55E);
  static const Color monacoGreenDeep = Color(0xFF16A34A);
  static const Color orbBlue = Color(0xFF1E3A8A);
  static const Color orbViolet = Color(0xFF7C3AED);

  // ── Material ───────────────────────────────────────────────────────────
  /// Resplandor del borde superior-izquierdo (reflejo de luz).
  static const Color edgeHighlight = Color(0x55FFFFFF);

  /// Sombra del borde inferior-derecho (hundimiento).
  static const Color edgeShadow = Color(0x40000000);

  /// Contorno base uniforme bajo el gradient direccional.
  static const Color borderBase = Color(0x2EFFFFFF);

  // ── Blur sigma ─────────────────────────────────────────────────────────
  static const double blurSubtle = 14;
  static const double blurDefault = 22;
  static const double blurHeavy = 30;

  // ── Radios ─────────────────────────────────────────────────────────────
  static const double radiusPill = 999;
  static const double radiusSmall = 14;
  static const double radiusCard = 22;
  static const double radiusCardLarge = 28;
  static const double radiusGroup = 24;
  static const double radiusDock = 28;

  // ── Movimiento ─────────────────────────────────────────────────────────
  static const Duration tapDown = Duration(milliseconds: 160);
  static const Duration tapUp = Duration(milliseconds: 220);
  static const Duration enter = Duration(milliseconds: 240);
  static const Duration swap = Duration(milliseconds: 260);

  static const Curve curveEnter = Curves.easeOutCubic;
  static const Curve curveSwap = Curves.easeOutCubic;

  // ── Sombras ────────────────────────────────────────────────────────────
  static List<BoxShadow> cardLift() => const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 26,
          spreadRadius: -6,
          offset: Offset(0, 12),
        ),
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 6,
          spreadRadius: -2,
          offset: Offset(0, 2),
        ),
      ];

  static List<BoxShadow> pillLift() => const [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 14,
          spreadRadius: -3,
          offset: Offset(0, 5),
        ),
      ];

  static List<BoxShadow> dockLift() => const [
        BoxShadow(
          color: Color(0x80000000),
          blurRadius: 32,
          spreadRadius: -4,
          offset: Offset(0, 14),
        ),
        BoxShadow(
          color: Color(0x26000000),
          blurRadius: 8,
          spreadRadius: -2,
          offset: Offset(0, 2),
        ),
      ];
}
