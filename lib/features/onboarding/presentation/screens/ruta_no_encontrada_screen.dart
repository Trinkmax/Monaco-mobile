import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../widgets/onboarding_scaffold.dart';

/// Lo que se ve cuando go_router no encuentra ruta para una ubicación.
///
/// Sin `errorBuilder`, go_router 14 dibuja su `MaterialErrorScreen`: una
/// AppBar que dice **"Page Not Found"** y, debajo, el `toString()` de la
/// excepción («GoException: no routes for location: /catalog») sobre fondo
/// blanco. En una app en español, con tema oscuro, eso se lee como app rota —y
/// llega solo: los `link_value` de la cartelera y de las campañas los tipea el
/// dueño a mano en `/dashboard/app-movil`, y rutas como `/catalog` o
/// `/elegir-sucursal` existieron y ya no existen.
///
/// La pantalla **no muestra la excepción**: al cliente no le sirve y al
/// desarrollador le llega por `debugPrint`. Y ofrece una sola salida, que es
/// la única que siempre funciona.
class RutaNoEncontradaScreen extends StatelessWidget {
  /// Lo que se intentó abrir. Sólo para el log; no se dibuja.
  final String? ubicacion;

  const RutaNoEncontradaScreen({super.key, this.ubicacion});

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      centered: true,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      footer: OnboardingCta(
        label: 'Ir al inicio',
        icon: Icons.home_rounded,
        onPressed: () => context.go('/home'),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MonacoLogo.monogram(width: 50),
          const SizedBox(height: 30),
          LiquidGlass(
            width: 96,
            height: 96,
            borderRadius: 48,
            padding: EdgeInsets.zero,
            pressable: false,
            showVignette: false,
            child: const Center(
              child: Icon(
                Icons.explore_off_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 26),
          const OnboardingTitle(
            align: TextAlign.center,
            title: 'No encontramos\nesa pantalla',
            subtitle:
                'Puede ser un enlace viejo o con un error. Volvé al inicio y '
                'seguí desde ahí.',
          ),
          const SizedBox(height: 10),
          Text(
            'Si llegaste desde una notificación, avisanos y lo corregimos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MonacoColors.textPrimary.withValues(alpha: 0.4),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
