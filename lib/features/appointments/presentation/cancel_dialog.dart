import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/utils/constants.dart';

import '../data/appointment_model.dart';
import '../data/fechas.dart';
import 'widgets/turno_links.dart';

/// Confirmación en dos pasos para cancelar un turno (mismo copy que el
/// turnero web). Devuelve `true` si el cliente confirmó.
///
/// [sena] es la seña del turno, si tiene: **cancelar plata sin nombrarla es lo
/// que genera el reclamo**. Ver `_AvisoSena` para qué se dice y qué no.
Future<bool> confirmCancelAppointment(
  BuildContext context, {
  required String summary,
  required int cancellationMinHours,
  AppointmentDeposit? sena,
}) async {
  final res = await showLiquidDialog<bool>(
    context,
    title: '¿Seguro que querés cancelar?',
    icon: Icons.event_busy_rounded,
    iconColor: MonacoColors.destructive,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          summary,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'El horario se libera para otro cliente y no se puede deshacer.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        if (sena != null && sena.plataDelLocal) ...[
          const SizedBox(height: 12),
          _AvisoSena(sena: sena),
        ],
        const SizedBox(height: 8),
        Text(
          'Podés cancelar hasta ${Fechas.horas(cancellationMinHours)} antes del turno.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
    actions: const [
      LiquidDialogAction<bool>(label: 'Mantener turno', value: false),
      LiquidDialogAction<bool>(label: 'Sí, cancelar', value: true, destructive: true),
    ],
  );
  return res == true;
}

/// Qué pasa con la seña.
///
/// **Nombra el monto y NO promete la devolución.** La app sabe que hay una seña
/// pagada y cuánto (`booking_deposits`, que el cliente lee por RLS), pero la
/// decisión la toma el server al cancelar (`resolverSenaDeTurnoCancelado`) a
/// partir de `branch_deposit_settings.refund_on_early_cancel`, que el cliente
/// NO puede leer y que el dueño puede cambiar cuando quiera. Prometer acá "te
/// devolvemos la seña" sería inventar una respuesta que ni siquiera pedimos:
/// `POST /api/mobile/turnos/cancel` contesta `{ok:true}` y nada más.
///
/// Cuando la API devuelva el desenlace real (ver el TODO del coordinador), esto
/// pasa a decir la frase exacta que el motor ya escribe ("Te devolvimos la seña
/// por Mercado Pago").
class _AvisoSena extends StatelessWidget {
  final AppointmentDeposit sena;
  const _AvisoSena({required this.sena});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: MonacoColors.warning.withValues(alpha: 0.10),
        border: Border.all(
          color: MonacoColors.warning.withValues(alpha: 0.32),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 16, color: MonacoColors.warning),
              const SizedBox(width: 9),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      height: 1.42,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      const TextSpan(text: 'Este turno tiene una seña de '),
                      TextSpan(
                        text: Fechas.moneda(sena.amount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(
                        text: ' pagada. Qué pasa con esa plata lo define la '
                            'política de cancelación de la sucursal, la misma '
                            'que aceptaste al pagar: si corresponde devolución, '
                            'se hace por Mercado Pago y puede tardar unos días. '
                            'Te avisamos por WhatsApp.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  abrirUrlExterna(context, AppConstants.termsOfServiceUrl),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Ver política de cancelación',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
