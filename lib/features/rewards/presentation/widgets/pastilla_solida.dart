import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

/// Pastilla **blanca opaca** con texto oscuro: el chip seleccionado y el saldo
/// de puntos.
///
/// No es un `LiquidPill` con tint blanco: el vidrio compone un degradado que
/// termina en `tint × 0.55`, o sea 50 % de blanco abajo a la derecha, y sobre
/// ese gris el texto negro pierde contraste justo en la esquina donde termina
/// la palabra. En una interfaz de vidrio hace falta un elemento sólido para que
/// "seleccionado" se lea de un vistazo; este es ese elemento.
///
/// Conserva el squish de todo lo tocable ([LiquidTapEffect]) para que no se
/// sienta de otra familia.
class PastillaSolida extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const PastillaSolida({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(15, 9, 15, 9),
    this.borderRadius = 999,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final cuerpo = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 12,
            spreadRadius: -3,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return cuerpo;
    return LiquidTapEffect(
      onTap: onTap!,
      scaleTo: 0.94,
      borderRadius: radius,
      child: cuerpo,
    );
  }
}
