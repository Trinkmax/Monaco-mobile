// Capturas para las FICHAS DE TIENDA (App Store y Play), sin login ni red.
//
//   QA_SHOTS_DIR=store/capturas/ios-6.9 flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/store_shots_test.dart \
//     -d 0E8B6324-7F0B-4713-9EA7-623C915DC70E
//
// El simulador tiene que ser un **iPhone 17 Pro Max** (1320×2868 @3x): es
// exactamente el tamaño 6.9" que pide App Store Connect. La captura la saca
// `IntegrationTestPlugin` con la escala de la pantalla y sólo con las ventanas
// de la app, así que sale sin barra de estado y sin alpha, que es lo que Apple
// acepta. Las variantes de Play (1080×2160) se derivan de estos PNG con
// ImageMagick — ver `store/README.md`.
//
// Diferencias con `wallet_preview_test.dart` / `alta_preview_test.dart`, que son
// bancos de prueba de diseño y no sirven tal cual para la tienda:
//
//   1. **Se pinta el shell real** (`MainShell` + `LiquidDock`) para las tres
//      pantallas que en la app viven dentro del dock (Inicio, Sucursales,
//      Premios). Los preview montan la pantalla suelta y salen sin dock, que es
//      justo lo que un comprador espera ver.
//   2. **Bienvenida, el wizard de turnos y Mi categoría van SIN dock**, porque
//      en la app tampoco lo tienen (están fuera del `ShellRoute`, ver
//      `lib/core/router/app_router.dart`). Una captura con un dock que la
//      pantalla real no tiene es una captura que miente.
//   3. **La persona es ficticia** ("Martín", 351 555-0123). Los preview usan el
//      nombre y el teléfono reales del desarrollador; una ficha de tienda es
//      pública.
//
// Nada de esto sale a la red: todos los providers están overrideados con datos
// fijos y el controller del wizard es de mentira (el real llama a la API en el
// constructor).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/router/app_router.dart';
import 'package:monaco_mobile/features/appointments/data/appointment_model.dart';
import 'package:monaco_mobile/features/appointments/data/booking_models.dart';
import 'package:monaco_mobile/features/appointments/presentation/booking_wizard_screen.dart';
import 'package:monaco_mobile/features/appointments/presentation/my_appointments_screen.dart';
import 'package:monaco_mobile/features/appointments/providers/appointments_provider.dart';
import 'package:monaco_mobile/features/appointments/providers/booking_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/presentation/screens/categoria_screen.dart';
import 'package:monaco_mobile/features/loyalty/providers/loyalty_provider.dart';
import 'package:monaco_mobile/features/notifications/data/notification_model.dart';
import 'package:monaco_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:monaco_mobile/features/occupancy/presentation/screens/occupancy_screen.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';
import 'package:monaco_mobile/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:monaco_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:monaco_mobile/features/reviews/providers/reviews_provider.dart';
import 'package:monaco_mobile/features/rewards/presentation/screens/premios_screen.dart';
import 'package:monaco_mobile/features/rewards/providers/premios_provider.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Persona de la ficha — ficticia a propósito
// ═══════════════════════════════════════════════════════════════════════════

const _nombre = 'Martín';
const _telefono = '3515550123'; // +54 9 351 555-0123

// ── Fechas ────────────────────────────────────────────────────────────────

String _fecha(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime get _hoy {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Próximo día que NO sea domingo (la agenda de Monaco es lunes a sábado): si
/// cae domingo, la tira lo dibuja deshabilitado y la captura queda rara.
String _proximoDiaHabil(int desde) {
  var d = _hoy.add(Duration(days: desde));
  while (d.weekday == DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return _fecha(d);
}

// ═══════════════════════════════════════════════════════════════════════════
// Datos fijos
// ═══════════════════════════════════════════════════════════════════════════

final _turno = Appointment.fromJson({
  'id': 'a1',
  'organization_id': 'org',
  'branch_id': 'b3',
  'client_id': 'c1',
  'appointment_date': _proximoDiaHabil(1),
  'start_time': '18:30',
  'end_time': '19:15',
  'duration_minutes': 45,
  'status': 'confirmed',
  'source': 'app',
  'branches': {
    'id': 'b3',
    'name': 'Rondeau',
    'slug': 'rondeau',
    'timezone': 'America/Argentina/Buenos_Aires',
  },
  'barber': {'id': 's1', 'full_name': 'Fabri'},
  'appointment_services': [
    {
      'service': {'id': 'sv1', 'name': 'Corte + barba'},
      'sort_order': 0,
    },
  ],
});

/// Catálogo de vidriera: hay uno más caro que el saldo para que la línea de
/// progreso del Home tenga hacia dónde ir (se deriva del premio más barato que
/// el cliente todavía no puede pagar).
const _catalogo = <Map<String, dynamic>>[
  {
    'id': 'r1',
    'name': '20% off en tu próximo corte',
    'description': 'Descuento',
    'points_cost': 400,
    'is_free_service': false,
    'discount_pct': 20,
    'stock': null,
    'image_url': null,
    'category': null,
    'type': 'points_redemption',
  },
  {
    'id': 'r2',
    'name': 'Corte gratis',
    'description': 'Servicio',
    'points_cost': 900,
    'is_free_service': true,
    'discount_pct': null,
    'stock': null,
    'image_url': null,
    'category': null,
    'type': 'points_redemption',
  },
  {
    'id': 'r3',
    'name': 'Gorra Monaco',
    'description': 'Merch',
    'points_cost': 1100,
    'is_free_service': false,
    'discount_pct': null,
    'stock': 6,
    'image_url': null,
    'category': 'merch',
    'type': 'points_redemption',
  },
  {
    'id': 'r4',
    'name': 'Remera Monaco',
    'description': 'Merch',
    'points_cost': 1800,
    'is_free_service': false,
    'discount_pct': null,
    'stock': 4,
    'image_url': null,
    'category': 'merch',
    'type': 'points_redemption',
  },
  {
    'id': 'r5',
    'name': 'Kit de barba',
    'description': 'Merch',
    'points_cost': 2200,
    'is_free_service': false,
    'discount_pct': null,
    'stock': 3,
    'image_url': null,
    'category': 'merch',
    'type': 'points_redemption',
  },
];

const _convenios = <Map<String, dynamic>>[
  {
    'id': 'cv1',
    'title': '20% off en cualquier café',
    'discount_text': '20% off',
    'image_url': null,
    'valid_until': null,
    'partner': {'id': 'p1', 'business_name': 'Café de la esquina', 'logo_url': null},
  },
  {
    'id': 'cv2',
    'title': '2x1 en pintas de 18 a 20',
    'discount_text': '2x1',
    'image_url': null,
    'valid_until': null,
    'partner': {'id': 'p2', 'business_name': 'Bar del centro', 'logo_url': null},
  },
  {
    'id': 'cv3',
    'title': 'Primera semana sin cargo',
    'discount_text': '1 semana',
    'image_url': null,
    'valid_until': null,
    'partner': {'id': 'p3', 'business_name': 'Gimnasio Norte', 'logo_url': null},
  },
];

final _wallet = <Map<String, dynamic>>[
  {
    'reward_id': 'r1',
    'client_reward_id': 'cr1',
    'reward_name': '20% off en tu próximo corte',
    'reward_description': 'Descuento',
    'reward_type': 'points_redemption',
    'discount_pct': 20,
    'is_free_service': false,
    'status': 'available',
    'qr_code': 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
    'expires_at': DateTime.now().add(const Duration(days: 12)).toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
    'image_url': null,
    'points_cost': 400,
    'category': null,
  },
  {
    'reward_id': 'r2',
    'client_reward_id': 'cr2',
    'reward_name': 'Corte gratis',
    'reward_description': 'Servicio',
    'reward_type': 'points_redemption',
    'discount_pct': null,
    'is_free_service': true,
    'status': 'available',
    'qr_code': 'ffeeddccbbaa99887766554433221100',
    'expires_at': DateTime.now().add(const Duration(days: 25)).toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
    'image_url': null,
    'points_cost': 900,
    'category': null,
  },
];

/// Las tres sucursales reales de Monaco (Córdoba), con la fila en vivo en tres
/// estados distintos: es lo que la captura tiene que contar.
const _sucursales = <Map<String, dynamic>>[
  {
    'branch_id': 'b1',
    'branch_name': 'Caseros',
    'occupancy_level': 'sin_espera',
    'is_open': true,
    'total_barbers': 3,
    'eta_minutes': 0,
  },
  {
    'branch_id': 'b2',
    'branch_name': 'Paraná',
    'occupancy_level': 'media',
    'is_open': true,
    'total_barbers': 6,
    'eta_minutes': 25,
  },
  {
    'branch_id': 'b3',
    'branch_name': 'Rondeau',
    'occupancy_level': 'baja',
    'is_open': true,
    'total_barbers': 4,
    'eta_minutes': 15,
  },
];

// ── Programa de fidelización (seed de la mig 202) ─────────────────────────

Map<String, dynamic> _tierJson(
  String code,
  String name,
  int sort,
  int min,
  int? max,
  int mult,
  String p,
  String s,
  String t,
  List<String> b,
) => {
  'code': code,
  'name': name,
  'sort': sort,
  'min_visits': min,
  'max_visits': max,
  'multiplier_pct': mult,
  'color_primary': p,
  'color_secondary': s,
  'text_color': t,
  'benefits': b,
};

final _tiers = [
  _tierJson('bronce', 'Bronce', 1, 0, 2, 100, '#7A4A22', '#C78A4E', '#FFFFFF', [
    'Sumás puntos en cada visita',
    'Acceso al catálogo de premios',
  ]),
  _tierJson('plata', 'Plata', 2, 3, 5, 105, '#3E444D', '#A9B1BA', '#FFFFFF', [
    '5 % más de puntos por visita',
    'Premios exclusivos Plata',
  ]),
  _tierJson('oro', 'Oro', 3, 6, 8, 110, '#7A5A12', '#D8AE3C', '#FFFFFF', [
    '10 % más de puntos por visita',
    'Premios exclusivos Oro',
    'Prioridad en novedades',
  ]),
  _tierJson('platinum', 'Platinum', 4, 9, null, 115, '#0B0B0D', '#3A3A44', '#FFFFFF', [
    '15 % más de puntos por visita',
    'Premios exclusivos Platinum',
    'Beneficios en comercios asociados',
  ]),
];

LoyaltySummary _loyaltyOro({int saldo = 1250}) => LoyaltySummary.fromJson({
  'program': {
    'enabled': true,
    'base_points': 100,
    'expiry_days': 120,
    'window_weeks': 12,
    'grace_days': 14,
    'welcome_bonus_points': 100,
  },
  'client': {
    'id': 'c1',
    'name': _nombre,
    'member_since': '2024-05-08T15:20:00Z',
  },
  'tier': _tiers[2],
  'next_tier': {..._tiers[3], 'faltan': 2},
  'visits_in_window': 7,
  'grace': null,
  'points': {
    'balance': saldo,
    'expiring_soon_points': 0,
    'expiring_soon_days': 14,
    'next_expiry_at': DateTime.now().add(const Duration(days: 96)).toUtc().toIso8601String(),
    'next_expiry_points': 220,
    'earned_total': saldo + 900,
    'redeemed_total': 900,
  },
  'referral': {
    'enabled': true,
    'code': 'MNC4H8TR',
    'discount_pct': 20,
    'referred_points': 100,
    'referrer_points': 150,
    'completed_count': 2,
  },
  'tiers': _tiers,
});

// ═══════════════════════════════════════════════════════════════════════════
// Auth de mentira (el real arranca escuchando a Supabase)
// ═══════════════════════════════════════════════════════════════════════════

class _FakeAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _cliente = AuthState(
  status: AuthStatus.authenticated,
  clientId: 'c1',
  clientName: _nombre,
  clientPhone: _telefono,
);

const _sinCuenta = AuthState(status: AuthStatus.unauthenticated);

List<Override> _overrides({
  AuthState auth = _cliente,
  bool conTurno = true,
  int saldo = 1250,
}) => [
  authProvider.overrideWith((ref) => _FakeAuth(auth)),
  loyaltyProvider.overrideWith((ref) async => _loyaltyOro(saldo: saldo)),
  catalogoPremiosProvider.overrideWith((ref) async => _catalogo),
  conveniosProvider.overrideWith((ref) async => _convenios),
  clientWalletProvider.overrideWith((ref) async => _wallet),
  branchSignalsProvider.overrideWith((ref) async => _sucursales),
  pendingReviewsProvider.overrideWith((ref) async => const []),
  billboardProvider.overrideWith((ref) async => const []),
  upcomingAppointmentsProvider.overrideWith(
    (ref) async => conTurno ? [_turno] : const <Appointment>[],
  ),
  pastAppointmentsProvider.overrideWith((ref) async => const <Appointment>[]),
  hayTurnosOnlineProvider.overrideWith((ref) => true),
  notificationsStreamProvider.overrideWith(
    (ref) => Stream.value(const <ClientNotification>[]),
  ),
  unreadNotificationsCountProvider.overrideWith((ref) => 2),
];

// ═══════════════════════════════════════════════════════════════════════════
// Wizard de turnos — controller de mentira
// ═══════════════════════════════════════════════════════════════════════════

/// El real sale a la API en el constructor (`_init()`), así que para la captura
/// se reemplaza por uno que sólo sostiene el estado. `canProceed` se implementa
/// de verdad porque el `build` de la pantalla lo lee (con el forwarder de
/// `noSuchMethod` tiraría `NoSuchMethodError` al pintar).
class _FakeWizard extends StateNotifier<BookingWizardState>
    implements BookingWizardController {
  _FakeWizard(super.state);

  @override
  bool get canProceed =>
      state.selectedDate != null && state.selectedSlot != null && state.policyAccepted;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Paso 3 del wizard (Día y horario) con una hora ya elegida y la política
/// aceptada: es el momento en que la pantalla muestra todo lo que sabe hacer
/// (tira de días, quién te atiende, grilla por franja y el resumen del pie).
BookingWizardState _estadoDelWizard() {
  final fecha = _proximoDiaHabil(1);
  final boot = BookingBootstrap.fromJson({
    'server_today': _fecha(_hoy),
    'server_now': DateTime.now().toUtc().toIso8601String(),
    'bookable': true,
    'branch': {
      'id': 'b3',
      'name': 'Rondeau',
      'slug': 'rondeau',
      'address': 'Bv. Rondeau 145',
      'timezone': 'America/Argentina/Buenos_Aires',
      'operation_mode': 'hybrid',
    },
    'settings': {
      'max_advance_days': 15,
      'appointment_days': [1, 2, 3, 4, 5, 6],
      'slot_interval_minutes': 15,
      'cancellation_min_hours': 2,
      'lead_time_minutes': 30,
      'buffer_minutes': 0,
    },
    'branding': {'welcome_message': null},
    'services': [
      {
        'id': 'sv1',
        'name': 'Corte + barba',
        'price': 22000,
        'duration_minutes': 45,
        'booking_mode': 'self_service',
      },
      {
        'id': 'sv2',
        'name': 'Corte',
        'price': 16000,
        'duration_minutes': 30,
        'booking_mode': 'self_service',
      },
    ],
    'staff': [
      {
        'id': 's1',
        'full_name': 'Fabri',
        'days': [1, 2, 3, 4, 5, 6],
        'windows': {
          for (final d in [1, 2, 3, 4, 5, 6])
            '$d': [
              {'start': '10:00', 'end': '13:00'},
              {'start': '15:00', 'end': '20:00'},
            ],
        },
      },
      {
        'id': 's2',
        'full_name': 'Simón',
        'days': [2, 4, 6],
        'windows': {
          for (final d in [2, 4, 6])
            '$d': [
              {'start': '15:00', 'end': '20:00'},
            ],
        },
      },
    ],
    'walk_in_staff': [
      {'id': 's3', 'full_name': 'Nico'},
    ],
    'client': {'first_name': _nombre, 'last_name': '', 'phone': _telefono},
    'deposit': {'enabled': false},
  });

  const horas = [
    ('10:00', true),
    ('10:45', true),
    ('11:30', true),
    ('12:15', false),
    ('15:00', true),
    ('15:45', true),
    ('16:30', true),
    ('17:15', false),
    ('18:00', true),
    ('18:45', true),
    ('19:30', true),
  ];

  final grupo = SlotGroup(
    staffId: 's1',
    staffName: 'Fabri',
    slots: [
      for (final (hora, libre) in horas) SlotItem(time: hora, available: libre),
    ],
  );

  return BookingWizardState(
    phase: WizardPhase.slot,
    slug: 'rondeau',
    bootstrap: boot,
    selectedServiceIds: const ['sv1'],
    selectedDate: fecha,
    slotsByDate: {fecha: SlotsOutcome.ok([grupo])},
    selectedSlot: const SlotSelection(
      time: '11:30',
      staffId: 's1',
      staffName: 'Fabri',
    ),
    policyAccepted: true,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// App de la captura — el MISMO shell que la app real
// ═══════════════════════════════════════════════════════════════════════════

/// `MainShell` (dock Liquid Glass) para las rutas que en `app_router.dart` viven
/// dentro del `ShellRoute`, y rutas sueltas para las que no (bienvenida, wizard,
/// categoría). Espeja la topología real: lo que acá tenga dock, en la app tiene
/// dock.
Widget _app(String initial) => MaterialApp.router(
  debugShowCheckedModeBanner: false,
  theme: MonacoTheme.dark,
  routerConfig: GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (_, _, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (_, _) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/turnos',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: MyAppointmentsScreen()),
          ),
          GoRoute(
            path: '/occupancy',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: OccupancyScreen()),
          ),
          GoRoute(
            path: '/rewards',
            pageBuilder: (_, _) => const NoTransitionPage(child: PremiosScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, _) => const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/categoria', builder: (_, _) => const CategoriaScreen()),
      GoRoute(
        path: '/turnos/reservar',
        builder: (_, _) => const BookingWizardScreen(),
      ),
    ],
  ),
);

Future<void> shot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name, {
  int frames = 10,
}) async {
  // Hay animaciones en loop (el LED de la fila, la banda de brillo de la
  // tarjeta, los orbes del fondo): `pumpAndSettle` no termina nunca.
  for (var i = 0; i < frames; i++) {
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
    // Sin esto, el Home lee la última categoría vista del Keychain real del
    // simulador y podría abrir la celebración de "subiste de categoría" encima
    // de la captura.
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('01 — Bienvenida', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(auth: _sinCuenta, conTurno: false),
        child: _app('/welcome'),
      ),
    );
    await shot(binding, tester, '01_bienvenida');
  });

  testWidgets('02 — Inicio con turno y tarjeta Oro', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _overrides(), child: _app('/home')),
    );
    await shot(binding, tester, '02_inicio');
  });

  testWidgets('03 — Sucursales con la fila en vivo', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _overrides(), child: _app('/occupancy')),
    );
    await shot(binding, tester, '03_sucursales');
  });

  testWidgets('04 — Reservar turno (día y horario)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._overrides(),
          bookingWizardProvider.overrideWith(
            (ref, slug) => _FakeWizard(_estadoDelWizard()),
          ),
        ],
        child: _app('/turnos/reservar'),
      ),
    );
    await shot(binding, tester, '04_turno');
  });

  testWidgets('05 — Premios', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _overrides(), child: _app('/rewards')),
    );
    await shot(binding, tester, '05_premios');
  });

  testWidgets('06 — Mi categoría', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: _overrides(), child: _app('/categoria')),
    );
    await shot(binding, tester, '06_categoria');
  });
}
