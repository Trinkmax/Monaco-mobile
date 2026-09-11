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

/// Flujo completo "activar notificaciones": pre-prompt → prompt nativo del
/// sistema → toast con el resultado. Devuelve el estado resultante (`null` si
/// el cliente canceló el pre-prompt o si Firebase no está configurado — en ese
/// caso la sección ni siquiera se dibuja).
///
/// **Siempre pasa por [PushService.requestPermission]**, incluso si el estado
/// leído decía `denied`: en Android ése es el estado de fábrica y es la única
/// llamada que dispara el diálogo de POST_NOTIFICATIONS. Si de verdad está
/// bloqueado, el sistema contesta al instante y el toast ofrece Ajustes.
Future<PushPermiso?> requestPushWithPrePrompt(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!PushService.isAvailable) return null;
  final accepted = await showPushPrePrompt(context);
  if (!accepted) return null;

  final permiso = await PushService.requestPermission();
  ref.invalidate(pushPermisoProvider);
  if (!context.mounted) return permiso;

  switch (permiso) {
    case PushPermiso.concedido:
      showLiquidToast(
        context,
        'Notificaciones activadas.',
        tone: LiquidToastTone.success,
      );
    case PushPermiso.bloqueado:
      showLiquidToast(
        context,
        'El permiso está bloqueado. Activalo desde los ajustes del sistema.',
        tone: LiquidToastTone.error,
        actionLabel: 'Ajustes',
        onAction: () => abrirAjustesDePush(context),
      );
    case PushPermiso.sinPedir:
    case PushPermiso.desconocido:
    case PushPermiso.noDisponible:
      break;
  }
  return permiso;
}

/// Abre los ajustes de la app: `app-settings:` en iOS, la ficha de la app en
/// Android. Si el sistema no lo permite, dicta el camino.
Future<void> abrirAjustesDePush(BuildContext context) async {
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
