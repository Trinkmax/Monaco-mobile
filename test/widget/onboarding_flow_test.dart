import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/core/auth/pin_service.dart';
import 'package:monaco_mobile/features/onboarding/presentation/screens/login_code_screen.dart';
import 'package:monaco_mobile/features/onboarding/presentation/screens/login_name_screen.dart';
import 'package:monaco_mobile/features/onboarding/presentation/screens/login_phone_screen.dart';
import 'package:monaco_mobile/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:monaco_mobile/features/onboarding/providers/login_flow_provider.dart';
import 'package:monaco_mobile/features/profile/presentation/screens/pin_setup_screen.dart';

/// Smoke de las pantallas de onboarding que no necesitan Supabase para
/// dibujarse (welcome, teléfono, código, nombre, alta de PIN). El `submit`
/// real contra `client-auth` no se ejercita acá: eso toca `authProvider`, que
/// exige `Supabase.initialize`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  late GoRouter router;

  Widget harness({
    required String initial,
    List<Override> overrides = const [],
  }) {
    router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
        GoRoute(path: '/login', builder: (_, _) => const LoginPhoneScreen()),
        GoRoute(
          path: '/login/codigo',
          builder: (_, _) => const LoginCodeScreen(),
        ),
        GoRoute(
          path: '/login/nombre',
          builder: (_, _) => const LoginNameScreen(),
        ),
        GoRoute(path: '/pin-setup', builder: (_, _) => const PinSetupScreen()),
      ],
    );
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(theme: MonacoTheme.dark, routerConfig: router),
    );
  }

  // Las pantallas tienen animaciones infinitas (orbes, LEDs): no se puede
  // usar pumpAndSettle. Avanzamos el reloj a mano.
  Future<void> settle(WidgetTester t, [int ms = 900]) async {
    await t.pump();
    await t.pump(Duration(milliseconds: ms));
  }

  testWidgets('welcome: tres slides, Empezar lleva a /login', (t) async {
    await t.pumpWidget(harness(initial: '/welcome'));
    await settle(t);

    expect(find.textContaining('Tu barbería'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
    expect(find.text('Ya tengo cuenta'), findsOneWidget);

    await t.tap(find.text('Siguiente'));
    await settle(t);
    expect(find.textContaining('Sumá puntos'), findsOneWidget);

    await t.tap(find.text('Siguiente'));
    await settle(t);
    expect(find.textContaining('Turnos en'), findsOneWidget);
    expect(find.text('Empezar'), findsOneWidget);

    await t.tap(find.text('Empezar'));
    await settle(t);
    expect(find.text('Ingresá tu número'), findsOneWidget);
  });

  testWidgets('teléfono: formatea en vivo y valida antes de llamar al server', (
    t,
  ) async {
    await t.pumpWidget(harness(initial: '/login'));
    await settle(t);

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(find.text('+54 9'), findsOneWidget);

    await t.enterText(field, '3512125');
    await settle(t, 300);
    expect(find.text('351 212-5'), findsOneWidget);

    // Incompleto + enviar → error de campo, sin tocar authProvider.
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t, 400);
    expect(find.textContaining('sin el 0 ni el 15'), findsOneWidget);

    await t.enterText(field, '+54 9 351 212 5249');
    await settle(t, 300);
    // El hint del campo es justamente "351 212-5249" (queda en el árbol con
    // opacidad 0 cuando hay texto), así que se mira el controller y no el
    // finder de texto.
    expect(t.widget<TextField>(field).controller!.text, '351 212-5249');
    expect(find.textContaining('sin el 0 ni el 15'), findsNothing);
  });

  testWidgets('código: sin flujo muestra "Este paso venció"', (t) async {
    await t.pumpWidget(harness(initial: '/login/codigo'));
    await settle(t);
    expect(find.text('Este paso venció'), findsOneWidget);
  });

  testWidgets('código: cliente nuevo → el código viaja al paso del nombre', (
    t,
  ) async {
    final flow = LoginFlow(
      phone: '3512125249',
      phoneMasked: '+54 9 351 ••• 5249',
      clientKnown: false,
      firstName: null,
      resendIn: 45,
      expiresIn: 600,
      sentAt: DateTime.now(),
    );
    await t.pumpWidget(
      harness(
        initial: '/login/codigo',
        overrides: [loginFlowProvider.overrideWith((ref) => flow)],
      ),
    );
    await settle(t);

    expect(find.text('Revisá tu WhatsApp'), findsOneWidget);
    expect(find.textContaining('+54 9 351 ••• 5249'), findsOneWidget);
    expect(find.textContaining('Reenviar en 0:4'), findsOneWidget);
    expect(find.text('Cambiar número'), findsOneWidget);

    await t.enterText(find.byType(TextField), '123456');
    await settle(t);

    expect(find.text('¿Cómo te llamás?'), findsOneWidget);
    // Es un `push`: la uri de la configuración sigue siendo la base, el
    // destino está en el último match.
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/login/nombre',
    );
  });

  testWidgets('código: al volver del nombre con error lo muestra y vacía', (
    t,
  ) async {
    final flow = LoginFlow(
      phone: '3512125249',
      phoneMasked: '+54 9 351 ••• 5249',
      clientKnown: false,
      firstName: null,
      resendIn: 45,
      expiresIn: 600,
      sentAt: DateTime.now(),
    );
    await t.pumpWidget(
      harness(
        initial: '/login/codigo',
        overrides: [loginFlowProvider.overrideWith((ref) => flow)],
      ),
    );
    await settle(t);
    final container = ProviderScope.containerOf(
      t.element(find.byType(LoginCodeScreen)),
    );

    await t.enterText(find.byType(TextField), '123456');
    await settle(t);
    expect(find.text('¿Cómo te llamás?'), findsOneWidget);

    // El paso del nombre "vuelve" con el error que dejó el server.
    final notifier = container.read(loginFlowProvider.notifier);
    notifier.state = notifier.state!.copyWith(
      pendingCodeError: 'El código venció. Pedí uno nuevo.',
      clearCode: true,
    );
    router.pop();
    await settle(t, 600);

    expect(find.text('Revisá tu WhatsApp'), findsOneWidget);
    expect(find.text('El código venció. Pedí uno nuevo.'), findsOneWidget);
    // El error se consumió (no se vuelve a mostrar) y el código se vació.
    expect(container.read(loginFlowProvider)!.pendingCodeError, isNull);
    expect(container.read(loginFlowProvider)!.code, isNull);
    // Vencido → "Reenviar código" disponible aunque el countdown no terminó.
    expect(find.text('Reenviar código'), findsOneWidget);
  });

  testWidgets('código: cliente conocido saluda por el nombre', (t) async {
    final flow = LoginFlow(
      phone: '3512125249',
      phoneMasked: '+54 9 351 ••• 5249',
      clientKnown: true,
      firstName: 'Nacho',
      resendIn: 0,
      expiresIn: 600,
      sentAt: DateTime.now(),
    );
    await t.pumpWidget(
      harness(
        initial: '/login/codigo',
        overrides: [loginFlowProvider.overrideWith((ref) => flow)],
      ),
    );
    await settle(t);
    expect(find.text('Hola de nuevo, Nacho'), findsOneWidget);
    expect(find.text('Reenviar código'), findsOneWidget);
  });

  testWidgets('nombre: exige al menos 2 letras y arma la vista previa', (
    t,
  ) async {
    final flow = LoginFlow(
      phone: '3512125249',
      phoneMasked: '+54 9 351 ••• 5249',
      clientKnown: false,
      firstName: null,
      resendIn: 45,
      expiresIn: 600,
      sentAt: DateTime.now(),
      code: '123456',
    );
    await t.pumpWidget(
      harness(
        initial: '/login/nombre',
        overrides: [loginFlowProvider.overrideWith((ref) => flow)],
      ),
    );
    await settle(t);

    expect(find.text('¿Cómo te llamás?'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));

    await t.enterText(fields.first, 'Ignacio');
    await settle(t, 300);
    expect(find.text('Hola, Ignacio'), findsOneWidget);
  });

  testWidgets('PIN: rechaza obvios, confirma en dos pasos y guarda el hash', (
    t,
  ) async {
    await t.pumpWidget(harness(initial: '/welcome'));
    await settle(t);
    router.push('/pin-setup');
    await settle(t);

    expect(find.text('Elegí un PIN'), findsOneWidget);

    Future<void> tapPin(String pin) async {
      for (final d in pin.split('')) {
        await t.tap(find.text(d));
        await t.pump(const Duration(milliseconds: 60));
      }
    }

    // 1234 es obvio: no avanza.
    await tapPin('1234');
    await settle(t, 700);
    expect(find.text('Elegí un PIN'), findsOneWidget);
    expect(find.textContaining('menos obvio'), findsOneWidget);

    await tapPin('2580');
    await settle(t, 500);
    expect(find.text('Confirmá tu PIN'), findsOneWidget);

    // Confirmación que no coincide → vuelve al paso 1.
    await tapPin('2581');
    await settle(t, 900);
    expect(find.text('Elegí un PIN'), findsOneWidget);

    await tapPin('2580');
    await settle(t, 500);
    await tapPin('2580');
    await settle(t, 900);

    expect(await PinService.hasPin(), isTrue);
    expect(await PinService.verifyPin('2580'), isTrue);
    // Volvió a la pantalla anterior.
    expect(router.routerDelegate.currentConfiguration.uri.path, '/welcome');
  });
}
