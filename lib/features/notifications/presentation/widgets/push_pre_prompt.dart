import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/push/push_service.dart';

/// Pre-prompt contextual (Apple 4.5.4) ANTES del diálogo nativo de
/// notificaciones. Devuelve `true` si el cliente quiere seguir.
Future<bool> showPushPrePrompt(BuildContext context) async {
  final ok = await showLiquidDialog<bool>(
    context,
    title: 'Activar notificaciones',
    icon: Icons.notifications_active_rounded,
    iconColor: MonacoColors.monacoGreen,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Con tu permiso te avisamos cuando:',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        const _Bullet(
          icon: Icons.alarm_rounded,
          text: 'Se acerca tu turno o cambia algo del mismo',
        ),
        const _Bullet(
          icon: Icons.card_giftcard_rounded,
          text: 'Sumás puntos o desbloqueás un premio',
        ),
        const _Bullet(
          icon: Icons.campaign_rounded,
          text: 'Hay novedades o promociones para vos',
        ),
        const SizedBox(height: 12),
        Text(
          'En el siguiente paso, el sistema te pide confirmación. Después podés '
          'elegir qué recibir desde Preferencias.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    ),
    actions: const [
      LiquidDialogAction(label: 'Ahora no', value: false),
      LiquidDialogAction(label: 'Continuar', value: true, primary: true),
    ],
  );
  return ok == true;
}

/// Flujo completo "activar notificaciones": pre-prompt → prompt nativo →
/// toast con el resultado. Devuelve el estado resultante (`null` = Firebase
/// no configurado o cancelado por el usuario).
Future<AuthorizationStatus?> requestPushWithPrePrompt(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!PushService.isAvailable) {
    showLiquidToast(
      context,
      'Las notificaciones no están disponibles en esta versión de la app.',
      tone: LiquidToastTone.info,
    );
    return null;
  }
  final accepted = await showPushPrePrompt(context);
  if (!accepted) return null;

  final status = await PushService.requestPermission();
  ref.invalidate(pushPermissionProvider);
  if (!context.mounted) return status;

  if (PushService.isGranted(status)) {
    showLiquidToast(
      context,
      'Notificaciones activadas.',
      tone: LiquidToastTone.success,
    );
  } else if (status == AuthorizationStatus.denied) {
    showLiquidToast(
      context,
      'El permiso está bloqueado. Activalo desde los ajustes del sistema.',
      tone: LiquidToastTone.error,
      actionLabel: 'Ajustes',
      onAction: () => openPushSettingsOrExplain(context),
    );
  }
  return status;
}

/// Abre Ajustes (iOS) o explica el camino (Android, que no tiene URL).
Future<void> openPushSettingsOrExplain(BuildContext context) async {
  final opened = await PushService.openSystemSettings();
  if (opened || !context.mounted) return;
  showLiquidToast(
    context,
    'Ajustes > Aplicaciones > Monaco > Notificaciones.',
    tone: LiquidToastTone.info,
    duration: const Duration(seconds: 4),
  );
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Bullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: [
                  MonacoColors.monacoGreen.withValues(alpha: 0.26),
                  MonacoColors.monacoGreen.withValues(alpha: 0.10),
                ],
              ),
              border: Border.all(
                color: MonacoColors.monacoGreen.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Icon(icon, size: 14, color: MonacoColors.monacoGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
