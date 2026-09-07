import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:monaco_mobile/features/onboarding/presentation/widgets/muro_login.dart';

/// Cabecera del Home: marca a la izquierda, campana a la derecha.
///
/// El wordmark en vez del nombre de una sucursal es el cambio de fondo de todo
/// este rediseño: la app es de Monaco, no del local al que fuiste una vez.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noLeidas = ref.watch(unreadNotificationsCountProvider);
    final invitado = ref.watch(authProvider.select((a) => a.isGuest));

    return Row(
      children: [
        // 150 px de ancho ≈ 36 de alto (el asset es 2000×482).
        const MonacoLogo.wordmark(width: 150),
        const Spacer(),
        _Campana(
          count: noLeidas,
          // La campana sigue estando para el invitado: esconderla haría que la
          // cabecera cambie de forma según el estado de sesión. Lo que cambia
          // es el destino — la bandeja es personal, así que va al muro.
          onTap: invitado
              ? () => pedirCuenta(context, ref, AccionConCuenta.notificaciones)
              : () => context.push('/notificaciones'),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _Campana extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _Campana({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hay = count > 0;
    return Semantics(
      button: true,
      label: hay ? 'Notificaciones, $count sin leer' : 'Notificaciones',
      child: LiquidTapEffect(
        onTap: onTap,
        scaleTo: 0.9,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  hay
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  color: Colors.white.withValues(alpha: hay ? 1 : 0.85),
                  size: 24,
                ),
              ),
              if (hay)
                Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 17),
                        height: 17,
                        padding: const EdgeInsets.symmetric(horizontal: 4.5),
                        decoration: BoxDecoration(
                          color: MonacoColors.brandRed,
                          borderRadius: BorderRadius.circular(999),
                          // El anillo del color del fondo separa el globo del ícono
                          // que tiene debajo; sin él, con 2+ dígitos, se leen como
                          // una sola mancha.
                          border: Border.all(
                            color: MonacoColors.background,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MonacoColors.brandRed.withValues(
                                alpha: 0.55,
                              ),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 1, end: 1.12, duration: 1200.ms),
            ],
          ),
        ),
      ),
    );
  }
}
