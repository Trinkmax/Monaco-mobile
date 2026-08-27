// Vista previa VISUAL del rediseño "wallet" (ago/2026), sin login ni red.
//
//   QA_SHOTS_DIR=build/wallet-shots flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/wallet_preview_test.dart -d <udid-simulador>
//
// Pinta el Home y la pantalla de Premios con datos fijos —los del diseño, no
// los de producción, que hoy tiene 2 premios sin foto— para poder mirar las
// tarjetas nuevas, los chips y la tira de "listos para usar" sin depender del
// catálogo del dueño ni de tener sesión.
//
// No reemplaza a `qa_flow_test.dart` (ese sí recorre la app real contra la
// API): esto es el banco de pruebas del diseño.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/features/appointments/data/appointment_model.dart';
import 'package:monaco_mobile/features/appointments/providers/appointments_provider.dart';
import 'package:monaco_mobile/features/appointments/providers/booking_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:monaco_mobile/features/notifications/data/notification_model.dart';
import 'package:monaco_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';
import 'package:monaco_mobile/features/points/providers/points_provider.dart';
import 'package:monaco_mobile/features/reviews/providers/reviews_provider.dart';
import 'package:monaco_mobile/features/rewards/presentation/screens/premios_screen.dart';
import 'package:monaco_mobile/features/rewards/providers/premios_provider.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

// ── Datos de muestra ───────────────────────────────────────────────────────

String _hoy() {
  final d = DateTime.now().add(const Duration(days: 3));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final _turno = Appointment.fromJson({
  'id': 'a1',
  'organization_id': 'org',
  'branch_id': 'b1',
  'client_id': 'c1',
  'appointment_date': _hoy(),
  'start_time': '18:30',
  'end_time': '19:15',
  'duration_minutes': 45,
  'status': 'confirmed',
  'source': 'app',
  'branches': {
    'id': 'b1',
    'name': 'Paraná',
    'slug': 'parana',
    'timezone': 'America/Argentina/Buenos_Aires',
  },
  'barber': {'id': 's1', 'full_name': 'Fabri'},
  'appointment_services': [
    {'service': {'id': 'sv1', 'name': 'Corte + barba'}, 'sort_order': 0},
  ],
});

const _catalogo = <Map<String, dynamic>>[
  {
    'id': 'r1',
    'name': 'Corte gratis',
    'description': 'Servicio',
    'points_cost': 300,
    'is_free_service': true,
    'discount_pct': null,
    'stock': null,
    'image_url': null,
    'category': null,
    'type': 'points_redemption',
  },
  {
    'id': 'r2',
    'name': 'Gorra Monaco',
    'description': 'Merch',
    'points_cost': 450,
    'is_free_service': false,
    'discount_pct': null,
    'stock': 5,
    'image_url': null,
    'category': 'merch',
    'type': 'points_redemption',
  },
  {
    'id': 'r3',
    'name': 'Remera Monaco',
    'description': 'Merch',
    'points_cost': 600,
    'is_free_service': false,
    'discount_pct': null,
    'stock': null,
    'image_url': null,
    'category': 'merch',
    'type': 'points_redemption',
  },
  {
    'id': 'r4',
    'name': '20% off en el próximo corte',
    'description': 'Descuento',
    'points_cost': 120,
    'is_free_service': false,
    'discount_pct': 20,
    'stock': null,
    'image_url': null,
    'category': null,
    'type': 'points_redemption',
  },
];

const _convenios = <Map<String, dynamic>>[
  {
    'id': 'b1',
    'title': '20% off en cualquier café',
    'discount_text': '20% off',
    'image_url': null,
    'valid_until': null,
    'partner': {'id': 'p1', 'business_name': 'Café Roma', 'logo_url': null},
  },
  {
    'id': 'b2',
    'title': '2x1 en pintas de 6 a 8',
    'discount_text': '2x1 pinta',
    'image_url': null,
    'valid_until': null,
    'partner': {'id': 'p2', 'business_name': 'Bar Ítaca', 'logo_url': null},
  },
  {
    'id': 'b3',
    'title': 'Una semana de prueba',
    'discount_text': '1 semana',
    'image_url': null,
    'valid_until': null,
    'partner': {'id': 'p3', 'business_name': 'Gym Norte', 'logo_url': null},
  },
];

final _wallet = <Map<String, dynamic>>[
  {
    'reward_id': 'r1',
    'client_reward_id': 'cr1',
    'reward_name': 'Corte gratis',
    'reward_description': 'Servicio',
    'reward_type': 'points_redemption',
    'discount_pct': null,
    'is_free_service': true,
    'status': 'available',
    'qr_code': 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
    'expires_at':
        DateTime.now().add(const Duration(days: 12)).toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
    'image_url': null,
    'points_cost': 300,
    'category': null,
  },
  {
    'reward_id': 'r4',
    'client_reward_id': 'cr2',
    'reward_name': '20% off en el próximo corte',
    'reward_description': 'Descuento',
    'reward_type': 'points_redemption',
    'discount_pct': 20,
    'is_free_service': false,
    'status': 'available',
    'qr_code': 'ffeeddccbbaa99887766554433221100',
    'expires_at': DateTime.now().add(const Duration(days: 4)).toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
    'image_url': null,
    'points_cost': 120,
    'category': null,
  },
];

const _sucursales = <Map<String, dynamic>>[
  {
    'branch_id': 'b1',
    'branch_name': 'Caseros',
    'occupancy_level': 'sin_espera',
    'is_open': true,
    'total_barbers': 2,
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
    'total_barbers': 5,
    'eta_minutes': 25,
  },
];

/// AuthNotifier de mentira: `AuthNotifier` real arranca escuchando Supabase.
class _FakeAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeAuth()
      : super(const AuthState(
          status: AuthStatus.authenticated,
          clientId: 'c1',
          clientName: 'Nacho Baldovino',
          clientPhone: '3512125249',
        ));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

List<Override> _overrides({required bool conTurno, required int saldo}) => [
      authProvider.overrideWith((ref) => _FakeAuth()),
      globalPointsProvider.overrideWith((ref) async => {
            'total_balance': saldo,
            'total_earned': saldo + 1860,
            'total_redeemed': 1860,
          }),
      catalogoPremiosProvider.overrideWith((ref) async => _catalogo),
      conveniosProvider.overrideWith((ref) async => _convenios),
      clientWalletProvider.overrideWith((ref) async => _wallet),
      branchSignalsProvider.overrideWith((ref) async => _sucursales),
      pendingReviewsProvider.overrideWith((ref) async => const []),
      billboardProvider.overrideWith((ref) async => const []),
      upcomingAppointmentsProvider
          .overrideWith((ref) async => conTurno ? [_turno] : const []),
      hayTurnosOnlineProvider.overrideWith((ref) => true),
      notificationsStreamProvider.overrideWith(
        (ref) => Stream.value(const <ClientNotification>[]),
      ),
      unreadNotificationsCountProvider.overrideWith((ref) => 3),
    ];

Widget _app(Widget home) {
  return MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: MonacoTheme.dark,
    routerConfig: GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => home)],
    ),
  );
}

Future<void> shot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  // Las pantallas tienen animaciones en loop (LED que pulsa, badge que respira):
  // `pumpAndSettle` nunca termina. Se bombean frames a mano.
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

  testWidgets('Home — con turno y saldo', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(conTurno: true, saldo: 240),
      child: _app(const HomeScreen()),
    ));
    await shot(binding, tester, 'wallet_01_home');

    await tester.drag(find.byType(SingleChildScrollView).first,
        const Offset(0, -520), warnIfMissed: false);
    await shot(binding, tester, 'wallet_02_home_scroll');
  });

  testWidgets('Home — sin turno (CTA ancho) y saldo alto', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(conTurno: false, saldo: 1200),
      child: _app(const HomeScreen()),
    ));
    await shot(binding, tester, 'wallet_03_home_sin_turno');
  });

  testWidgets('Home — cliente nuevo, saldo 0', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(conTurno: false, saldo: 0),
      child: _app(const HomeScreen()),
    ));
    await shot(binding, tester, 'wallet_04_home_saldo_cero');
  });

  testWidgets('Premios — grilla, chips y tira de listos', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(conTurno: true, saldo: 240),
      child: _app(const PremiosScreen()),
    ));
    await shot(binding, tester, 'wallet_05_premios');

    for (final chip in const ['Cortes', 'Merch', 'Marcas']) {
      final f = find.text(chip);
      if (f.evaluate().isEmpty) continue;
      await tester.tap(f.first, warnIfMissed: false);
      await shot(binding, tester, 'wallet_06_premios_${chip.toLowerCase()}');
    }

    final todo = find.text('Todo');
    if (todo.evaluate().isNotEmpty) {
      await tester.tap(todo.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.drag(find.byType(CustomScrollView).first,
        const Offset(0, -420), warnIfMissed: false);
    await shot(binding, tester, 'wallet_07_premios_scroll');
  });
}
