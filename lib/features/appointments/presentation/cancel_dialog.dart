import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../data/fechas.dart';

/// Confirmación en dos pasos para cancelar un turno (mismo copy que el
/// turnero web). Devuelve `true` si el cliente confirmó.
Future<bool> confirmCancelAppointment(
  BuildContext context, {
  required String summary,
  required int cancellationMinHours,
}) async {
  final res = await showLiquidDialog<bool>(
    context,
    title: '¿Seguro que querés cancelar?',
    icon: Icons.event_busy_rounded,
    iconColor: MonacoColors.destructive,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
