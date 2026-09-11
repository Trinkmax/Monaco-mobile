import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/core/push/push_handler.dart';

/// La ruta que promete un push no se puede perder mientras el cliente resuelve
/// su PIN o su Face ID: antes se descartaba a los 20 s y el push terminaba
/// abriendo Home, justo para los que activaron seguridad.
void main() {
  GoRouter armarRouter(GlobalKey<NavigatorState> key, String inicial) {
    return GoRouter(
      navigatorKey: key,
      initialLocation: inicial,
      routes: [
        GoRoute(path: '/pin', builder: (_, _) => const _Pantalla('pin')),
        GoRoute(
          path: '/welcome',
          builder: (_, _) => const _Pantalla('welcome'),
        ),
        GoRoute(path: '/home', builder: (_, _) => const _Pantalla('home')),
        GoRoute(path: '/visits', builder: (_, _) => const _Pantalla('visits')),
      ],
    );
  }

  tearDown(PushHandler.debugReset);

  test('la clasificación de rutas separa gates de "sin sesión"', () {
    expect(PushHandler.esperaPara('/pin'), EsperaDePush.gate);
    expect(PushHandler.esperaPara('/biometric'), EsperaDePush.gate);
    expect(PushHandler.esperaPara('/splash'), EsperaDePush.gate);
    expect(PushHandler.esperaPara('/welcome'), EsperaDePush.sinSesion);
    expect(PushHandler.esperaPara('/login'), EsperaDePush.sinSesion);
    expect(PushHandler.esperaPara('/login/codigo'), EsperaDePush.sinSesion);
    expect(PushHandler.esperaPara('/home'), EsperaDePush.navegar);
    expect(PushHandler.esperaPara('/points'), EsperaDePush.navegar);
  });

  test('las rutas del shell se reconocen (la bandeja usa la misma lista)', () {
    expect(PushHandler.esRutaDeShell('/rewards'), isTrue);
    expect(PushHandler.esRutaDeShell('/turnos'), isTrue);
    expect(PushHandler.esRutaDeShell('/mis-premios'), isFalse);
    expect(PushHandler.esRutaDeShell('/review/abc?x=1'), isFalse);
  });

  testWidgets('en el gate del PIN la ruta espera y navega al salir', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final router = armarRouter(key, '/pin');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    PushHandler.setNavigatorKey(key);

    PushHandler.navigateTo('/visits');

    // 30 s > el tope viejo de 20 s: antes de este arreglo, acá ya se había
    // descartado.
    await tester.pump(const Duration(seconds: 30));
    expect(PushHandler.rutaPendiente, '/visits');
    expect(find.text('pin'), findsOneWidget);

    // El cliente desbloquea: el router sale del gate y el push aterriza.
    // Se mira la pantalla y no `currentConfiguration.uri`: un `push`
    // imperativo apila la ruta sin cambiar la uri de la configuración.
    router.go('/home');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(PushHandler.rutaPendiente, isNull);
    expect(find.text('visits'), findsOneWidget);
  });

  testWidgets('sin sesión la ruta se descarta a los 20 s', (tester) async {
    final key = GlobalKey<NavigatorState>();
    final router = armarRouter(key, '/welcome');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    PushHandler.setNavigatorKey(key);

    PushHandler.navigateTo('/visits');
    await tester.pump(const Duration(seconds: 10));
    expect(PushHandler.rutaPendiente, '/visits');

    await tester.pump(const Duration(seconds: 15));
    expect(PushHandler.rutaPendiente, isNull);
    expect(find.text('welcome'), findsOneWidget);
    expect(find.text('visits'), findsNothing);
  });
}

class _Pantalla extends StatelessWidget {
  final String nombre;
  const _Pantalla(this.nombre);

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(nombre)));
}
