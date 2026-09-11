import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/push/push_service.dart';
import 'package:monaco_mobile/features/notifications/presentation/widgets/push_pre_prompt.dart'
    show abrirAjustesDePush;

import '../../data/push_offer_store.dart';

/// **El pedido contextual del permiso de notificaciones.**
///
/// Se ofrece UNA vez en la vida del dispositivo, y justo después de que el
/// turno queda confirmado: es el único momento en que el valor del permiso se
/// explica solo. Los productores reales de push en producción son los
/// recordatorios de turno (`push_24h` / `push_2h`) y los avisos de cambio, así
/// que pedirlo únicamente desde Perfil → Notificaciones —donde entra quien ya
/// fue a buscarlo— deja el opt-in cerca de cero.
///
/// Reglas, en orden:
///  1. **Sin Firebase configurado no aparece nada.** `PushService.isAvailable`
///     es `false` mientras `firebase_options.dart` tenga los placeholders, que
///     es como está hoy: ofrecer un permiso que no se puede pedir sería un
///     diálogo que no hace nada.
///  2. **Nunca a un invitado**: sin cuenta no hay turnos ni token que registrar.
///  3. Sólo con el permiso en [PushPermiso.sinPedir] —o sea, el prompt del
///     sistema nunca se disparó— y si **no se ofreció antes**
///     ([PushOfrecidoStore]). `bloqueado` queda afuera: ahí el diálogo nativo
///     ya no aparece y lo único que se puede ofrecer es un viaje a Ajustes,
///     que no es lo que uno quiere leer justo después de reservar.
///  4. Es un pre-prompt propio (Apple 4.5.4): el diálogo NATIVO sale recién si
///     el cliente toca "Sí, avisame". Un "Ahora no" no gasta la única
///     oportunidad que da iOS de preguntar.
Future<void> ofrecerAvisosDeTurno(BuildContext context, WidgetRef ref) async {
  if (!PushService.isAvailable) return;
  if (ref.read(authProvider).isGuest) return;

  final store = ref.read(pushOfrecidoStoreProvider);
  if (await store.yaSeOfrecio()) return;

  // `sinPedir` es lo único que habilita: cubre el `notDetermined` de iOS y el
  // `denied` de fábrica de Android 13+ (ver el comentario largo de
  // `PushPermiso`).
  if (await PushService.currentPermiso() != PushPermiso.sinPedir) return;
  if (!context.mounted) return;

  // Se marca ANTES de mostrar: si el cliente cierra la app con el diálogo
  // abierto, la oferta ya fue.
  await store.marcarOfrecido();
  if (!context.mounted) return;

  final quiere = await _preguntar(context);
  if (quiere != true || !context.mounted) return;

  final permiso = await PushService.requestPermission();
  ref.invalidate(pushPermisoProvider);
  if (!context.mounted) return;

  switch (permiso) {
    case PushPermiso.concedido:
      showLiquidToast(
        context,
        'Listo, te avisamos antes del turno.',
        tone: LiquidToastTone.success,
      );
    case PushPermiso.bloqueado:
      // El sistema puede contestar que no sin llegar a mostrar nada (Android
      // con el permiso ya negado): el único camino es Ajustes, y hay que
      // decirlo en vez de dejar la sensación de que el botón no hizo nada.
      showLiquidToast(
        context,
        'Quedaron desactivadas. Podés activarlas desde los ajustes del sistema.',
        tone: LiquidToastTone.info,
        actionLabel: 'Ajustes',
        onAction: () => abrirAjustesDePush(context),
      );
    case PushPermiso.sinPedir:
    case PushPermiso.desconocido:
    case PushPermiso.noDisponible:
      break;
  }
}

/// El pre-prompt, con el copy del momento: acá el cliente acaba de reservar,
/// así que la promesa concreta ("24 h y 2 h antes") vale más que la lista
/// genérica de todo lo que la app podría notificar.
Future<bool?> _preguntar(BuildContext context) {
  return showLiquidDialog<bool>(
    context,
    title: '¿Te recordamos el turno?',
    icon: Icons.alarm_rounded,
    iconColor: MonacoColors.monacoGreen,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Te avisamos 24 h y 2 h antes, y si el turno cambia o se cancela te '
          'enterás al toque.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'En el siguiente paso el sistema te pide confirmación. Después podés '
          'elegir qué recibir desde Perfil.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    ),
    actions: const [
      LiquidDialogAction<bool>(label: 'Ahora no', value: false),
      LiquidDialogAction<bool>(label: 'Sí, avisame', value: true, primary: true),
    ],
  );
}
