import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/appointments/data/fechas.dart';

import '../../providers/sena_estado_provider.dart';

/// "Tenés un pago sin confirmar."
///
/// Existe porque el pago ocurre FUERA de la app: mientras el cliente está en
/// Mercado Pago, iOS puede matar el proceso, y el deep link de vuelta puede no
/// llegar nunca (basta con que vuelva con el botón de atrás). Sin este cartel,
/// ese cliente tiene un cobro hecho y ninguna pantalla que se lo explique.
///
/// Se dibuja sólo si hay una seña vigente: nunca ocupa lugar en el caso normal.
class SenaPendienteBanner extends ConsumerWidget {
  /// Margen inferior cuando el cartel aparece (0 si no hay nada que mostrar).
  final double espacioAbajo;

  const SenaPendienteBanner({super.key, this.espacioAbajo = 14});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendiente = ref.watch(senaPendienteProvider).valueOrNull;
    if (pendiente == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: espacioAbajo),
      child: LiquidGlass(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        borderRadius: 22,
        tint: MonacoColors.warning,
        tintOpacity: 0.10,
        onTap: () => context.push('/pago/${pendiente.depositId}'),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MonacoColors.warning.withValues(alpha: 0.16),
                border: Border.all(color: MonacoColors.warning.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  size: 19, color: MonacoColors.warning),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tenés un pago sin confirmar',
                    style: TextStyle(
                      color: MonacoColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      'Seña ${Fechas.moneda(pendiente.monto)}',
                      if (pendiente.resumen.isNotEmpty) pendiente.resumen,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: Colors.white.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
