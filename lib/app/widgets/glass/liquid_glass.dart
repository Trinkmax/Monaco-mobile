import 'dart:ui';

import 'package:flutter/material.dart';

import 'liquid_tap_effect.dart';
import 'liquid_tokens.dart';

/// Lámina de "vidrio líquido" — la superficie base de iOS 26.
///
/// Incluye:
///   • Backdrop blur real sobre lo que haya detrás.
///   • Gradient de relleno con ligera inclinación topLeft → bottomRight.
///   • Sheen superior (reflejo de luz).
///   • Viñeta inferior-derecha (hundimiento).
///   • Stroke direccional (claro arriba/izquierda, oscuro abajo/derecha).
///   • Sombra suave que levita la lámina 2mm.
///   • Squish al tocar (si `onTap` está presente).
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? tint;
  final double tintOpacity;
  final double blur;
  final VoidCallback? onTap;
  final double scalePressed;
  final bool pressable;
  final bool showHighlight;
  final bool showVignette;
  final double? width;
  final double? height;
  final List<BoxShadow>? shadow;

  const LiquidGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = LiquidTokens.radiusCard,
    this.tint,
    this.tintOpacity = 0.09,
    this.blur = LiquidTokens.blurDefault,
    this.onTap,
    this.scalePressed = 0.97,
    this.pressable = true,
    this.showHighlight = true,
    this.showVignette = true,
    this.width,
    this.height,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final baseTint = tint ?? Colors.white;

    final inner = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseTint.withOpacity((tintOpacity * 2.4).clamp(0, 1)),
                baseTint.withOpacity((tintOpacity * 0.55).clamp(0, 1)),
              ],
            ),
            border: Border.all(
              color: LiquidTokens.borderBase,
              width: 0.8,
            ),
          ),
          child: Stack(
            children: [
              if (showHighlight) _TopSheen(borderRadius: borderRadius),
              if (showVignette) _BottomVignette(borderRadius: borderRadius),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _LiquidBorderPainter(radius: borderRadius),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );

    final framed = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow ?? LiquidTokens.cardLift(),
      ),
      child: inner,
    );

    if (onTap == null) return framed;

    if (!pressable) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: framed,
      );
    }

    return LiquidTapEffect(
      onTap: onTap!,
      scaleTo: scalePressed,
      borderRadius: radius,
      child: framed,
    );
  }
}

class _TopSheen extends StatelessWidget {
  final double borderRadius;
  const _TopSheen({required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 64,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(borderRadius),
              topRight: Radius.circular(borderRadius),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.14),
                Colors.white.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomVignette extends StatelessWidget {
  final double borderRadius;
  const _BottomVignette({required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      right: 0,
      width: 140,
      height: 90,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(borderRadius),
            ),
            gradient: RadialGradient(
              center: Alignment.bottomRight,
              radius: 1,
              colors: [
                Colors.black.withOpacity(0.14),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinta el stroke direccional (claro → transparente → oscuro diagonal).
class _LiquidBorderPainter extends CustomPainter {
  final double radius;
  const _LiquidBorderPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 1 || size.height <= 1) return;
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          LiquidTokens.edgeHighlight,
          Color(0x00FFFFFF),
          LiquidTokens.edgeShadow,
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidBorderPainter old) =>
      old.radius != radius;
}
