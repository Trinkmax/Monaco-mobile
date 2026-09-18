import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/pin_service.dart';
import 'package:monaco_mobile/core/auth/secure_storage.dart';
import 'package:monaco_mobile/core/auth/social_auth_service.dart';
import 'package:monaco_mobile/features/onboarding/presentation/screens/login_code_screen.dart';
import 'package:monaco_mobile/features/onboarding/presentation/screens/login_phone_screen.dart';
import 'package:monaco_mobile/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:monaco_mobile/features/onboarding/providers/login_flow_provider.dart';
import 'package:monaco_mobile/features/profile/presentation/screens/pin_setup_screen.dart';
import 'package:monaco_mobile/features/profile/presentation/screens/pin_verify_screen.dart';

/// Smoke de las pantallas de onboarding que no necesitan Supabase para
/// dibujarse (welcome, teléfono, código, alta de PIN). El `submit` real contra
/// `client-auth` no se ejercita acá: eso toca `authProvider`, que exige
/// `Supabase.initialize`. Donde hace falta el notifier (el "Seguir mirando")
/// se reemplaza por [_AuthFalso].
///
/// **Los botones de Google y Apple no aparecen en este harness**: se gatean con
/// `Platform.isIOS` / `Platform.isAndroid` y `flutter test` corre en el host
/// (macOS), donde los dos son `false`. Para verlos hay que correr la preview de
/// `integration_test/alta_preview_test.dart` en el simulador.
/// Auth de mentira: sólo sabe pasar a invitado. Con `implements`, cualquier
/// otro método que la pantalla llame revienta en el test, que es lo que se
/// quiere (que la bienvenida no dependa de más que esto).
class _AuthFalso extends StateNotifier<AuthState> implements AuthNotifier {
  _AuthFalso() : super(const AuthState(status: AuthStatus.unauthenticated));

  int invitadoLlamadas = 0;

  @override
  Future<void> continuarComoInvitado() async {
    invitadoLlamadas++;
    state = const AuthState(status: AuthStatus.guest);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

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
        // A dónde tiene que llegar "Seguir mirando". Sin redirect: acá se
        // prueba que el link NAVEGA solo, no que el router lo empuje.
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME DE INVITADO')),
        ),
        GoRoute(path: '/login', builder: (_, _) => const LoginPhoneScreen()),
        GoRoute(
          path: '/login/codigo',
          builder: (_, _) => const LoginCodeScreen(),
        ),
        GoRoute(path: '/pin-setup', builder: (_, _) => const PinSetupScreen()),
        GoRoute(path: '/pin', builder: (_, _) => const PinVerifyScreen()),
      ],
    );
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(theme: MonacoTheme.dark, routerConfig: router),
    );
  }

  // Las pantallas tienen animaciones infinitas (orbes, LEDs): no se puede
  // usar pumpAndSettle. Avanzamos el reloj a mano — y en VARIOS frames, no en
  // uno solo largo: un `AnimatedSwitcher` saca al hijo saliente recién en el
  // frame siguiente al que termina su animación, y el carrusel de bienvenida
  // encadena PageView → setState → switcher, que son tres frames como mínimo.
  Future<void> settle(WidgetTester t, [int ms = 900]) async {
    await t.pump();
    for (var i = 0; i < (ms / 150).ceil(); i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    await t.pump();
  }

  LoginFlow flujo({
    bool clientKnown = false,
    bool nameRequired = false,
    String? firstName,
    int resendIn = 45,
  }) => LoginFlow(
    phone: '3512125249',
    phoneMasked: '+54 9 351 ••• 5249',
    clientKnown: clientKnown,
    nameRequired: nameRequired,
    firstName: firstName,
    resendIn: resendIn,
    expiresIn: 600,
    sentAt: DateTime.now(),
  );

  /// El carrusel: "Continuar" dos veces deja la tercera lámina en pantalla,
  /// que es la única con las puertas de entrada.
  Future<void> irALaUltimaLamina(WidgetTester t) async {
    for (var i = 0; i < 2; i++) {
      await t.tap(find.text('Continuar'));
      await settle(t);
    }
  }

  testWidgets('welcome: "Continuar" avanza y las puertas están en la última', (
    t,
  ) async {
    await t.pumpWidget(harness(initial: '/welcome'));
    await settle(t);

    // Primera lámina: ilustración + copy + UN solo botón. Las formas de entrar
    // no compiten con el carrusel (rediseño del 18/sep/2026).
    expect(find.textContaining('Tu barbería'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Usar mi número de teléfono'), findsNothing);
    expect(find.text('Seguir mirando'), findsNothing);
    expect(find.textContaining('Al continuar aceptás'), findsNothing);

    await t.tap(find.text('Continuar'));
    await settle(t);
    expect(find.textContaining('Sumá puntos'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);

    await t.tap(find.text('Continuar'));
    await settle(t);
    expect(find.textContaining('Turnos en'), findsOneWidget);
    // Recién acá: el "Continuar" se fue y en su lugar están las puertas +
    // los legales.
    expect(find.text('Continuar'), findsNothing);
    expect(find.text('Usar mi número de teléfono'), findsOneWidget);
    // "Seguir mirando" (modo invitado) es requisito de la 5.1.1 y va acá,
    // visible sin scrollear, junto a las otras puertas.
    expect(find.text('Seguir mirando'), findsOneWidget);
    expect(find.textContaining('Al continuar aceptás'), findsOneWidget);
    // Lo que murió con el alta propia: la app ya no manda a nadie al local.
    expect(find.text('¿Aún no sos cliente?'), findsNothing);

    await t.tap(find.text('Usar mi número de teléfono'));
    await settle(t);
    expect(find.text('Ingresá tu número'), findsOneWidget);
  });

  testWidgets('welcome: "Seguir mirando" ENTRA al Home de invitado', (t) async {
    // El bug por el que el link se sacó el 12/sep/2026: cambiaba el estado a
    // `guest` y esperaba que el router lo moviera, pero `/welcome` está en la
    // lista blanca del invitado y el redirect contestaba "quedate". El link
    // tiene que navegar él mismo — y este harness no tiene redirect, así que
    // si llega al Home es porque navegó.
    final auth = _AuthFalso();
    await t.pumpWidget(
      harness(
        initial: '/welcome',
        overrides: [authProvider.overrideWith((ref) => auth)],
      ),
    );
    await settle(t);
    await irALaUltimaLamina(t);

    await t.tap(find.text('Seguir mirando'));
    await settle(t);

    expect(auth.invitadoLlamadas, 1);
    expect(auth.state.status, AuthStatus.guest);
    expect(find.text('HOME DE INVITADO'), findsOneWidget);
    expect(find.text('Seguir mirando'), findsNothing);
  });

  testWidgets('welcome: sin sociales, el teléfono es el botón PRIMARIO', (
    t,
  ) async {
    // En el host no hay Google ni Apple (se gatean por `Platform`), que es
    // exactamente la configuración con la que se manda a revisión si los
    // client IDs no están cargados. Antes la lámina sólida era sólo la de
    // Google: sin él, la bienvenida quedaba con pastillas translúcidas y
    // ningún botón principal.
    await t.pumpWidget(harness(initial: '/welcome'));
    await settle(t);
    await irALaUltimaLamina(t);

    // La pastilla activa del carrusel también es blanca (`seleccion`): lo que
    // distingue a la lámina de un botón es la sombra.
    final laminaBlanca = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == Colors.white &&
          (w.decoration as BoxDecoration).boxShadow != null,
    );
    // Una sola: el "Continuar" (también lámina blanca) ya no está.
    expect(laminaBlanca, findsOneWidget);
    expect(
      find.descendant(
        of: laminaBlanca,
        matching: find.text('Usar mi número de teléfono'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('welcome: entra en una pantalla chica sin desbordar', (t) async {
    // En un iPhone SE (320×568 lógicos) es donde revienta si el carrusel no
    // cede alto: la lámina ocupa todo lo que el texto le deja, y en la última
    // el pie pasa de un botón a las puertas de entrada + legales. Un overflow
    // de RenderFlex hace fallar el test.
    t.view.physicalSize = const Size(640, 1136);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(harness(initial: '/welcome'));
    await settle(t);
    expect(find.text('Continuar'), findsOneWidget);
    expect(t.takeException(), isNull);

    await irALaUltimaLamina(t);
    expect(find.text('Usar mi número de teléfono'), findsOneWidget);
    expect(t.takeException(), isNull);
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

  testWidgets('teléfono: con alta social pendiente explica por qué lo pide', (
    t,
  ) async {
    await t.pumpWidget(
      harness(
        initial: '/login',
        overrides: [
          signupPendienteProvider.overrideWith(
            (ref) => SignupPendiente(
              token: 'v1.token',
              proveedor: SocialProvider.google,
              nombreSugerido: 'Nacho Baldovino',
              email: 'nacho@gmail.com',
            ),
          ),
        ],
      ),
    );
    await settle(t);

    expect(find.text('Falta tu teléfono'), findsOneWidget);
    expect(find.textContaining('nacho@gmail.com'), findsOneWidget);
  });

  testWidgets('código: sin flujo muestra "Este paso venció"', (t) async {
    await t.pumpWidget(harness(initial: '/login/codigo'));
    await settle(t);
    expect(find.text('Este paso venció'), findsOneWidget);
  });

  testWidgets(
    'código: cliente conocido saluda por el nombre y no pide nombre',
    (t) async {
      await t.pumpWidget(
        harness(
          initial: '/login/codigo',
          overrides: [
            loginFlowProvider.overrideWith(
              (ref) =>
                  flujo(clientKnown: true, firstName: 'Nacho', resendIn: 0),
            ),
          ],
        ),
      );
      await settle(t);

      expect(find.text('Hola de nuevo, Nacho'), findsOneWidget);
      expect(find.text('Reenviar código'), findsOneWidget);
      expect(find.text('TU NOMBRE'), findsNothing);
      expect(find.text('Confirmar'), findsOneWidget);
    },
  );

  testWidgets(
    'código: teléfono nuevo → el NOMBRE se pide en la MISMA pantalla',
    (t) async {
      await t.pumpWidget(
        harness(
          initial: '/login/codigo',
          overrides: [
            loginFlowProvider.overrideWith((ref) => flujo(nameRequired: true)),
          ],
        ),
      );
      await settle(t);

      expect(find.text('Revisá tu WhatsApp'), findsOneWidget);
      expect(find.text('TU NOMBRE'), findsOneWidget);
      expect(find.text('Crear mi cuenta'), findsOneWidget);

      // El CTA no se habilita con el código solo: falta el nombre. Y el sexto
      // dígito NO auto-envía (el cliente todavía puede estar por escribirlo).
      final campos = find.byType(TextField);
      await t.enterText(campos.first, '123456');
      await settle(t, 400);
      expect(find.text('Revisá tu WhatsApp'), findsOneWidget);

      // Un nombre de una sola letra tampoco alcanza.
      await t.enterText(campos.last, 'I');
      await settle(t, 300);
      expect(find.text('Revisá tu WhatsApp'), findsOneWidget);
    },
  );

  testWidgets('código: el nombre que trajo Google llega precargado', (t) async {
    await t.pumpWidget(
      harness(
        initial: '/login/codigo',
        overrides: [
          loginFlowProvider.overrideWith((ref) => flujo(nameRequired: true)),
          signupPendienteProvider.overrideWith(
            (ref) => SignupPendiente(
              token: 'v1.token',
              proveedor: SocialProvider.google,
              nombreSugerido: 'Nacho Baldovino',
            ),
          ),
        ],
      ),
    );
    await settle(t);

    expect(find.text('Nacho Baldovino'), findsOneWidget);
  });

  testWidgets('cerrar sesión borra el PIN y la biometría del equipo', (
    t,
  ) async {
    // El gate es de ESTA cuenta en ESTE equipo: si sobrevive al logout, el que
    // entra después se encuentra un candado que no puede abrir (el PIN es un
    // hash local, no hay "olvidé mi PIN").
    await PinService.setPin('2580');
    await SecureStorageService.setBiometricEnabled(true);
    await SecureStorageService.setGuestMode(true);
    final secret = await SecureStorageService.getOrCreateDeviceSecret();

    await SecureStorageService.clearSession();

    expect(await PinService.hasPin(), isFalse);
    expect(await SecureStorageService.isPinEnabled(), isFalse);
    expect(await SecureStorageService.isBiometricEnabled(), isFalse);
    expect(await SecureStorageService.isGuestMode(), isFalse);
    // El device_secret NO se rota: es lo que habilita el login silencioso.
    expect(await SecureStorageService.getOrCreateDeviceSecret(), secret);
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
