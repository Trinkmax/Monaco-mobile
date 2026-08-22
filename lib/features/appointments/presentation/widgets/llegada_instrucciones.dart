import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

/// "Cuando llegues a la barbería": cómo registrar la llegada en la tablet.
///
/// - `tieneCara == true`: el cliente ya tiene la cara registrada → toca "Sí"
///   y mira la cámara.
/// - `tieneCara == false`: toca "No" y pone el teléfono (y le ofrecemos
///   registrar la cara).
/// - `tieneCara == null`: no sabemos (detalle de un turno viejo) → versión
///   neutra con los dos caminos.
class ComoRegistrarLlegada extends StatelessWidget {
  final bool? tieneCara;
  final bool esNuevo;

  const ComoRegistrarLlegada({super.key, required this.tieneCara, this.esNuevo = false});

  @override
  Widget build(BuildContext context) {
    final pasos = <List<InlineSpan>>[];
    String? nota;

    if (tieneCara == true) {
      pasos.add([
        const TextSpan(text: 'En la tablet de recepción vas a ver '),
        _b('¿Estás registrado?'),
        const TextSpan(text: '. Tocá '),
        _b('Sí'),
        const TextSpan(text: '.'),
      ]);
      pasos.add([
        const TextSpan(text: 'Mirá la cámara un segundo. Te reconoce sola y quedás anotado.'),
      ]);
      nota = 'Listo, no tenés que hacer nada más ni hablar con nadie. El barbero te llama cuando sea tu turno.';
    } else if (tieneCara == false) {
      pasos.add([
        const TextSpan(text: 'En la tablet de recepción vas a ver '),
        _b('¿Estás registrado?'),
        const TextSpan(text: '. Tocá '),
        _b('No'),
        const TextSpan(text: '.'),
        if (esNuevo) const TextSpan(text: ' Es tu primera vez, así que va por acá.'),
      ]);
      pasos.add([
        const TextSpan(
            text: 'Poné tu teléfono y listo: quedás anotado y el barbero te llama cuando sea tu turno.'),
      ]);
      nota = 'Aprovechá: después de poner el teléfono la tablet te ofrece Registrar mi cara. Si aceptás, la próxima entrás sin tocar nada.';
    } else {
      pasos.add([
        const TextSpan(text: 'En la tablet de recepción vas a ver '),
        _b('¿Estás registrado?'),
        const TextSpan(text: '. Si ya registraste tu cara, tocá '),
        _b('Sí'),
        const TextSpan(text: ' y mirá la cámara un segundo.'),
      ]);
      pasos.add([
        const TextSpan(text: 'Si no, tocá '),
        _b('No'),
        const TextSpan(text: ' y poné tu teléfono: quedás anotado y el barbero te llama cuando sea tu turno.'),
      ]);
    }

    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      borderRadius: 22,
      tintOpacity: 0.07,
      pressable: false,
      showVignette: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [
                      MonacoColors.monacoGreen.withValues(alpha: 0.26),
                      MonacoColors.monacoGreen.withValues(alpha: 0.10),
                    ],
                  ),
                  border: Border.all(
                    color: MonacoColors.monacoGreen.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: const Icon(Icons.tablet_mac_rounded,
                    size: 17, color: MonacoColors.monacoGreen),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Cuando llegues a la barbería',
                  style: TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < pasos.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _Paso(numero: i + 1, spans: pasos[i]),
          ],
          if (nota != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                nota,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static TextSpan _b(String t) => TextSpan(
        text: t,
        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
      );
}

class _Paso extends StatelessWidget {
  final int numero;
  final List<InlineSpan> spans;
  const _Paso({required this.numero, required this.spans});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
          ),
          child: Text(
            '$numero',
            style: const TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
                children: spans,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
