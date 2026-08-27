import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';

/// "Paso N de M · etiqueta" + barra segmentada (un segmento por paso, llenos
/// los ya recorridos y el actual). Reemplaza al stepper de círculos con
/// conectores, que desalineaba el último paso por construcción.
class StepProgress extends StatelessWidget {
  final int current; // 1-based
  final int total;
  final String label;

  const StepProgress({
    super.key,
    required this.current,
    required this.total,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Paso $current de $total',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            Text(
              label,
              style: const TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i < current
                        ? MonacoColors.seleccion.withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.10),
                    boxShadow: i < current
                        ? [
                            BoxShadow(
                              color: MonacoColors.seleccion.withValues(alpha: 0.30),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
