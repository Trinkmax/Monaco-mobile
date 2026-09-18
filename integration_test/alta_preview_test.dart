// Vista previa VISUAL del alta propia de cuentas y del modo invitado, sin
// login ni red.
//
//   QA_SHOTS_DIR=build/alta-shots flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/alta_preview_test.dart -d <udid-simulador> \
//     --dart-define=GOOGLE_IOS_CLIENT_ID=x.apps.googleusercontent.com
//
// **El `--dart-define` de arriba no es opcional para esta preview.** El botón
// de Google se dibuja sólo si hay client id cargado (`googleConfigurado`), así
// que sin él la pantalla de bienvenida sale con dos botones en vez de tres y no
// se ve lo que hay que mirar. El valor puede ser cualquier cosa: acá nadie
// llama a Google, sólo se pinta el botón.
//
// El de Apple aparece por ser iOS (`Platform.isIOS`); en un emulador Android no
// va a estar, y eso es correcto.
//
// Por qué existe: los overflows de esta pantalla no salen de `flutter test`.
// La bienvenida es un carrusel cuya lámina toma todo el alto que el texto le
// deja, y en la última el pie pasa de un botón a tres de 56 + legales; el muro
// de login es una hoja con copy variable — una columna sin constraint de alto
// crece lo que necesita y nunca desborda en un widget test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/features/appointments/presentation/my_appointments_screen.dart';
import 'package:monaco_mobile/features/appointments/providers/appointments_provider.dart';
import 'package:monaco_mobile/features/appointments/providers/booking_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:monaco_mobile/core/auth/social_auth_service.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/providers/loyalty_provider.dart';
import 'package:monaco_mobile/features/notifications/data/notification_model.dart';
import 'package:monaco_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';
import 'package:monaco_mobile/features/onboarding/presentation/screens/login_code_screen.dart';
import 'package:monaco_mobile/features/onboarding/presentation/screens/login_phone_screen.dart';
import 'package:monaco_mobile/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:monaco_mobile/features/onboarding/providers/login_flow_provider.dart';
import 'package:monaco_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:monaco_mobile/features/rewards/presentation/screens/premios_screen.dart';
import 'package:monaco_mobile/features/rewards/providers/premios_provider.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';
import 'package:monaco_mobile/features/reviews/providers/reviews_provider.dart';

const _sucursales = <Map<String, dynamic>>[
  {
    'branch_id': 'b1',
    'branch_name': 'Paraná',
    'occupancy_level': 'baja',
    'is_open': true,
    'total_barbers': 3,
  },
  {
    'branch_id': 'b2',
    'branch_name': 'Rondeau',
    'occupancy_level': 'media',
    'is_open': true,
    'total_barbers': 2,
  },
  {
    'branch_id': 'b3',
    'branch_name': 'Caseros',
    'occupancy_level': 'alta',
    'is_open': true,
    'total_barbers': 4,
  },
];

/// Auth de mentira en modo **invitado**: es lo que dispara todas las variantes
/// "sin cuenta" del Home, Turnos, Premios y Perfil.
class _AuthInvitado extends StateNotifier<AuthState> implements AuthNotifier {
  _AuthInvitado() : super(const AuthState(status: AuthStatus.guest));

  /// Lo único que la bienvenida le pide al notifier: "Seguir mirando".
  @override
  Future<void> continuarComoInvitado() async {
    state = const AuthState(status: AuthStatus.guest);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Todo lo personal viene vacío, que es exactamente lo que devuelven los
/// providers reales sin sesión (`clientId == null` → `const []`).
List<Override> _invitado() => [
  authProvider.overrideWith((ref) => _AuthInvitado()),
  loyaltyProvider.overrideWith((ref) async => LoyaltySummary.disabled()),
  catalogoPremiosProvider.overrideWith((ref) async => const []),
  conveniosProvider.overrideWith((ref) async => const []),
  clientWalletProvider.overrideWith((ref) async => const []),
  branchSignalsProvider.overrideWith((ref) async => _sucursales),
  pendingReviewsProvider.overrideWith((ref) async => const []),
  billboardProvider.overrideWith((ref) async => const []),
  upcomingAppointmentsProvider.overrideWith((ref) async => const []),
  pastAppointmentsProvider.overrideWith((ref) async => const []),
  // Falla abierto: sin cuenta la API de turnos devuelve 401 y el provider real
  // se queda en `true` para no esconder el CTA.
  hayTurnosOnlineProvider.overrideWith((ref) => true),
  notificationsStreamProvider.overrideWith(
    (ref) => Stream.value(const <ClientNotification>[]),
  ),
  unreadNotificationsCountProvider.overrideWith((ref) => 0),
];

Widget _app(Widget home, {List<GoRoute> extra = const []}) {
  return MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: MonacoTheme.dark,
    routerConfig: GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(path: '/login', builder: (_, _) => const LoginPhoneScreen()),
        GoRoute(
          path: '/login/codigo',
          builder: (_, _) => const LoginCodeScreen(),
        ),
        ...extra,
      ],
    ),
  );
}

Future<void> shot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  // Orbes del backdrop y badges que respiran: `pumpAndSettle` no termina nunca.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await binding.takeScreenshot(name);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('es_AR');
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Bienvenida — las puertas de entrada', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _invitado(),
        child: _app(
          const WelcomeScreen(),
          extra: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ],
        ),
      ),
    );
    await shot(binding, tester, 'alta_01_bienvenida');

    // Las tres láminas. La primera avanza con el botón (es lo que va a tocar
    // el cliente), la segunda con el gesto. La tercera es la que hay que
    // mirar: el pie pasa de "Continuar" a las tres puertas + legales y el
    // carrusel cede alto — es donde puede desbordar.
    await tester.tap(find.text('Continuar'));
    await shot(binding, tester, 'alta_02_bienvenida_slide2');
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await shot(binding, tester, 'alta_03_bienvenida_slide3');

    // "Seguir mirando" tiene que ENTRAR (era el bug): la captura siguiente es
    // el Home de invitado, no la bienvenida otra vez.
    await tester.tap(find.text('Seguir mirando'));
    await shot(binding, tester, 'alta_03b_seguir_mirando_entra');
  });

  testWidgets('Teléfono — alta social pendiente (Google)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._invitado(),
          signupPendienteProvider.overrideWith(
            (ref) => SignupPendiente(
              token: 'v1.token.demo',
              proveedor: SocialProvider.google,
              nombreSugerido: 'Nacho Baldovino',
              email: 'nacho.baldovino@gmail.com',
            ),
          ),
        ],
        child: _app(const LoginPhoneScreen()),
      ),
    );
    await shot(binding, tester, 'alta_04_telefono_desde_google');
  });

  testWidgets('Código — con el campo Nombre en la misma pantalla', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._invitado(),
          loginFlowProvider.overrideWith(
            (ref) => LoginFlow(
              phone: '3512125249',
              phoneMasked: '+54 9 351 ••• 5249',
              clientKnown: false,
              nameRequired: true,
              firstName: null,
              resendIn: 45,
              expiresIn: 600,
              sentAt: DateTime.now(),
            ),
          ),
        ],
        child: _app(const LoginCodeScreen()),
      ),
    );
    await shot(binding, tester, 'alta_05_codigo_con_nombre');
  });

  testWidgets('Home de invitado — tarjeta de invitación', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _invitado(), child: _app(const HomeScreen())),
    );
    await shot(binding, tester, 'alta_06_home_invitado');

    // El muro: es la pantalla que más puede crecer (copy variable + 3 botones
    // + legales) y la que hay que mirar con la hoja abierta.
    await tester.tap(find.text('Reservá tu turno'), warnIfMissed: false);
    await shot(binding, tester, 'alta_07_muro_reservar');
  });

  testWidgets('Turnos de invitado', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _invitado(),
        child: _app(const MyAppointmentsScreen()),
      ),
    );
    await shot(binding, tester, 'alta_08_turnos_invitado');
  });

  testWidgets('Premios de invitado — la vidriera', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _invitado(), child: _app(const PremiosScreen())),
    );
    await shot(binding, tester, 'alta_09_premios_vidriera');
  });

  testWidgets('Perfil de invitado', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _invitado(), child: _app(const ProfileScreen())),
    );
    await shot(binding, tester, 'alta_10_perfil_invitado');
  });
}
