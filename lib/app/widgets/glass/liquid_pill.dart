import 'package:flutter/material.dart';

import 'liquid_glass.dart';
import 'liquid_tokens.dart';

/// Versión compacta de [LiquidGlass] con forma de pastilla — pensado para
/// badges clickeables, acciones secundarias y chips de estado.
class LiquidPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? tint;
  final double tintOpacity;
  final double borderRadius;
  final double blur;

  const LiquidPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.onTap,
    this.tint,
    this.tintOpacity = 0.10,
    this.borderRadius = LiquidTokens.radiusPill,
    this.blur = LiquidTokens.blurSubtle,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: padding,
      borderRadius: borderRadius,
      tint: tint,
      tintOpacity: tintOpacity,
      onTap: onTap,
      showHighlight: false,
      showVignette: false,
      blur: blur,
      shadow: LiquidTokens.pillLift(),
      scalePressed: 0.94,
      child: child,
    );
  }
}

/// Botón glass primario (CTA). Más alto, tint verde Monaco, squish más marcado.
class LiquidButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final bool primary;
  final double borderRadius;

  const LiquidButton({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.tint,
    this.primary = true,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? (primary ? LiquidTokens.monacoGreen : Colors.white);
    return LiquidGlass(
      padding: padding,
      borderRadius: borderRadius,
      tint: accent,
      tintOpacity: primary ? 0.20 : 0.08,
      blur: LiquidTokens.blurSubtle,
      onTap: onPressed,
      scalePressed: 0.96,
      showVignette: false,
      shadow: primary
          ? [
              BoxShadow(
                color: accent.withOpacity(0.35),
                blurRadius: 18,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
              const BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                spreadRadius: -2,
                offset: Offset(0, 3),
              ),
            ]
          : LiquidTokens.pillLift(),
      child: Center(child: child),
    );
  }
}
