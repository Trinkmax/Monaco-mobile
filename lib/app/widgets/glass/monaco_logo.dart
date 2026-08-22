import 'package:flutter/material.dart';

/// Marca Monaco: monograma "M" o wordmark "MONACO [BARBER STUDIO]".
/// Los assets ya son blancos sobre transparente (con el rojo de los corchetes
/// en el wordmark); no aplicar filtros de color.
class MonacoLogo extends StatelessWidget {
  final double width;
  final bool wordmark;
  final Color? color;

  const MonacoLogo.monogram({super.key, this.width = 64, this.color})
      : wordmark = false;

  const MonacoLogo.wordmark({super.key, this.width = 220})
      : wordmark = true,
        color = null;

  @override
  Widget build(BuildContext context) {
    final asset = wordmark
        ? 'assets/images/monaco_wordmark.png'
        : 'assets/images/monaco_m.png';
    return Semantics(
      label: 'Monaco Barber Studio',
      image: true,
      child: Image.asset(
        asset,
        width: width,
        fit: BoxFit.contain,
        color: wordmark ? null : color,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
