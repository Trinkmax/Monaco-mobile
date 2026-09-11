import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/features/onboarding/presentation/screens/ruta_no_encontrada_screen.dart';

/// Una ruta desconocida no puede terminar en el `MaterialErrorScreen` de
/// go_router: AppBar "Page Not Found" en inglés + el `toString()` de la
/// excepción, en una app en español y oscura. Llega solo: los `link_value` de
/// la cartelera y de las campañas los tipea el dueño a mano.
void main() {
  Widget harness(GoRouter router) =>
      MaterialApp.router(theme: MonacoTheme.dark, routerConfig: router);

  // Las pantallas de onboarding tienen orbes que animan en loop: no se puede
  // `pumpAndSettle`.
  Future<void> settle(WidgetTester t, [int ms = 900]) async {
    await t.pump();
    await t.pump(Duration(milliseconds: ms));
  }

  testWidgets('la pantalla habla en español y no muestra la excepción', (
    t,
  ) async {
    await t.pumpWidget(
      harness(
        GoRouter(
          initialLocation: '/x',
          routes: [
            GoRoute(
              path: '/x',
              builder: (_, _) =>
                  const RutaNoEncontradaScreen(ubicacion: '/catalog'),
            ),
          ],
        ),
      ),
    );
    await settle(t);

    expect(find.textContaining('No encontramos'), findsOneWidget);
    expect(find.text('Ir al inicio'), findsOneWidget);
    expect(find.textContaining('Page Not Found'), findsNothing);
    expect(find.textContaining('GoException'), findsNothing);
    // Ni siquiera la ruta que falló: al cliente no le dice nada.
    expect(find.textContaining('/catalog'), findsNothing);
  });

  testWidgets('el errorBuilder atrapa una ruta que no existe', (t) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('inicio'))),
      ],
      errorBuilder: (context, state) =>
          RutaNoEncontradaScreen(ubicacion: state.uri.toString()),
    );
    await t.pumpWidget(harness(router));
    await settle(t);
    expect(find.text('inicio'), findsOneWidget);

    router.push('/elegir-sucursal');
    await settle(t);
    expect(find.textContaining('No encontramos'), findsOneWidget);

    // Y la salida devuelve al inicio de verdad.
    await t.tap(find.text('Ir al inicio'));
    await settle(t);
    expect(find.text('inicio'), findsOneWidget);
  });
}
