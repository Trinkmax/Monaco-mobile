import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';

import 'auth_opciones.dart';
import 'legal_footer.dart';
import 'onboarding_scaffold.dart';

/// Las acciones que necesitan cuenta. Cada una trae su propio copy: un muro que
/// dice siempre "iniciá sesión" no explica nada, y la razón por la que pedimos
/// el teléfono es distinta si vas a reservar (te tenemos que reconocer en el
/// local) que si vas a canjear (los puntos son de una persona).
enum AccionConCuenta {
  reservar,
  canjear,
  misTurnos,
  misPuntos,
  perfil,
  notificaciones,
  resenias,
}

extension _CopyAccion on AccionConCuenta {
  String get titulo => switch (this) {
    AccionConCuenta.reservar => 'Reservá tu turno',
    AccionConCuenta.canjear => 'Canjeá tus premios',
    AccionConCuenta.misTurnos => 'Tus turnos',
    AccionConCuenta.misPuntos => 'Tus puntos',
    AccionConCuenta.perfil => 'Tu perfil',
    AccionConCuenta.notificaciones => 'Tus avisos',
    AccionConCuenta.resenias => 'Contanos cómo te fue',
  };

  String get detalle => switch (this) {
    AccionConCuenta.reservar =>
      'Necesitamos tu teléfono para reconocerte cuando llegás al local y '
          'avisarte por WhatsApp si algo cambia.',
    AccionConCuenta.canjear =>
      'Los puntos y los premios son de cada cliente: creá tu cuenta para '
          'empezar a sumar en cada corte.',
    AccionConCuenta.misTurnos =>
      'Con tu cuenta ves tus turnos, la cuenta regresiva y podés cancelar '
          'sin llamar.',
    AccionConCuenta.misPuntos =>
      'Cada corte suma puntos y categoría. Creá tu cuenta y empezá a '
          'acumular desde la próxima visita.',
    AccionConCuenta.perfil =>
      'Tu nombre, tus visitas, tus premios y tus preferencias viven en tu '
          'cuenta.',
    AccionConCuenta.notificaciones =>
      'Te avisamos de tus turnos, tus premios y las novedades de Monaco.',
    AccionConCuenta.resenias =>
      'Las reseñas van atadas a tu visita, así el barbero sabe de quién es '
          'la devolución.',
  };

  IconData get icono => switch (this) {
    AccionConCuenta.reservar => Icons.calendar_month_rounded,
    AccionConCuenta.canjear => Icons.card_giftcard_rounded,
    AccionConCuenta.misTurnos => Icons.event_available_rounded,
    AccionConCuenta.misPuntos => Icons.stars_rounded,
    AccionConCuenta.perfil => Icons.person_rounded,
    AccionConCuenta.notificaciones => Icons.notifications_rounded,
    AccionConCuenta.resenias => Icons.rate_review_rounded,
  };
}

/// Muro de login para un invitado.
///
/// Devuelve `true` si al cerrarse el cliente quedó con sesión (y entonces el
/// llamador puede repetir la acción). Si el flujo siguió por teléfono, la hoja
/// se cierra y la navegación la maneja `/login`: el llamador recibe `false` y
/// no tiene que hacer nada.
///
/// **Siempre tiene "Ahora no"**, y cerrar la hoja deslizándola equivale a eso:
/// la guideline 5.1.1 pide que se pueda seguir usando la app sin cuenta, y un
/// muro sin salida visible es exactamente lo que se rechaza.
Future<bool> pedirCuenta(
  BuildContext context,
  WidgetRef ref,
  AccionConCuenta accion,
) async {
  final res = await showLiquidSheet<bool>(
    context,
    builder: (ctx) => _MuroLogin(accion: accion),
  );
  return res == true;
}

/// Atajo para pantallas que ya saben que el cliente es invitado: si tiene
/// cuenta ejecuta la acción; si no, abre el muro y la ejecuta al volver con
/// sesión.
Future<void> conCuenta(
  BuildContext context,
  WidgetRef ref,
  AccionConCuenta accion,
  VoidCallback accionar,
) async {
  if (ref.read(authProvider).tieneCuenta) {
    accionar();
    return;
  }
  final ok = await pedirCuenta(context, ref, accion);
  if (ok && context.mounted) accionar();
}

class _MuroLogin extends ConsumerWidget {
  final AccionConCuenta accion;
  const _MuroLogin({required this.accion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 0.8,
              ),
            ),
            child: Icon(accion.icono, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          accion.titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          accion.detalle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 22),
        AuthOpciones(
          // Sesión lista sin salir de la hoja (Google/Apple con la identidad ya
          // vinculada): se cierra devolviendo `true` para que el llamador
          // repita la acción que el cliente quiso hacer.
          onSesionLista: () => Navigator.of(context).pop(true),
          // El camino por teléfono navega a `/login`: la hoja se va antes para
          // no quedar apilada sobre la pantalla de login.
          onAntesDeNavegar: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(height: 6),
        Center(
          child: OnboardingLink(
            label: 'Ahora no',
            onTap: () => Navigator.of(context).pop(false),
          ),
        ),
        const SizedBox(height: 4),
        const LegalFooter(),
      ],
    );
  }
}
