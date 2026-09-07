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

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/appointments/presentation/widgets/day_strip.dart';
import 'package:monaco_mobile/features/appointments/presentation/widgets/step_progress.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/features/appointments/data/appointment_model.dart';
import 'package:monaco_mobile/features/appointments/providers/appointments_provider.dart';
import 'package:monaco_mobile/features/appointments/providers/booking_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/presentation/screens/categoria_screen.dart';
import 'package:monaco_mobile/features/loyalty/presentation/widgets/tier_up_celebration.dart';
import 'package:monaco_mobile/features/loyalty/providers/loyalty_provider.dart';
import 'package:monaco_mobile/features/notifications/data/notification_model.dart';
import 'package:monaco_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';
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

// ── Programa de fidelización (get_client_loyalty) ─────────────────────────

Map<String, dynamic> _tierJson(String code, String name, int sort, int min,
        int? max, int mult, String p, String s, String t, List<String> b) =>
    {
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

// Seed de la mig 202: texto SIEMPRE blanco y extremos claros oscurecidos.
final _tiers = [
  _tierJson('bronce', 'Bronce', 1, 0, 2, 100, '#7A4A22', '#C78A4E', '#FFFFFF',
      ['Sumás puntos en cada visita', 'Acceso al catálogo de premios']),
  _tierJson('plata', 'Plata', 2, 3, 5, 105, '#3E444D', '#A9B1BA', '#FFFFFF',
      ['5 % más de puntos por visita', 'Premios exclusivos Plata']),
  _tierJson('oro', 'Oro', 3, 6, 8, 110, '#7A5A12', '#D8AE3C', '#FFFFFF',
      ['10 % más de puntos por visita', 'Premios exclusivos Oro', 'Prioridad en novedades']),
  _tierJson('platinum', 'Platinum', 4, 9, null, 115, '#0B0B0D', '#3A3A44', '#FFFFFF',
      ['15 % más de puntos por visita', 'Premios exclusivos Platinum', 'Beneficios en comercios asociados']),
];

Map<String, dynamic> _programa() => {
      'enabled': true,
      'base_points': 100,
      'expiry_days': 120,
      'window_weeks': 12,
      'grace_days': 14,
      'welcome_bonus_points': 100,
    };

/// Cliente Oro: 7 visitas, faltan 2 para Platinum, 650 pts, 120 por vencer.
LoyaltySummary _loyaltyOro({int saldo = 650, bool gracia = false}) =>
    LoyaltySummary.fromJson({
      'program': _programa(),
      'client': {'id': 'c1', 'name': 'Nacho Baldovino', 'member_since': '2024-03-14T15:20:00Z'},
      'tier': _tiers[2],
      'next_tier': {..._tiers[3], 'faltan': 2},
      'visits_in_window': 7,
      'grace': gracia
          ? {
              'until': DateTime.now().add(const Duration(days: 5)).toUtc().toIso8601String(),
              'days_left': 5,
              'tier_after_code': 'plata',
              'tier_after_name': 'Plata',
            }
          : null,
      'points': {
        'balance': saldo,
        'expiring_soon_points': 120,
        'expiring_soon_days': 14,
        'next_expiry_at': DateTime.now().add(const Duration(days: 12)).toUtc().toIso8601String(),
        'next_expiry_points': 120,
        'earned_total': saldo + 600,
        'redeemed_total': 600,
      },
      'referral': {'enabled': true, 'code': 'MNC7K2PQ', 'discount_pct': 20, 'referred_points': 100, 'referrer_points': 150, 'completed_count': 1},
      'tiers': _tiers,
    });

LoyaltySummary _loyaltyPlatinum({int saldo = 2400}) => LoyaltySummary.fromJson({
      'program': _programa(),
      'client': {'id': 'c1', 'name': 'Nacho Baldovino', 'member_since': '2023-06-01T15:20:00Z'},
      'tier': _tiers[3],
      'next_tier': null,
      'visits_in_window': 11,
      'grace': null,
      'points': {'balance': saldo, 'expiring_soon_points': 0, 'expiring_soon_days': 14, 'next_expiry_at': null, 'next_expiry_points': 0},
      'referral': {'enabled': true, 'code': 'MNC7K2PQ'},
      'tiers': _tiers,
    });

/// Lo que devuelve la RPC hoy en prod (programa apagado).
LoyaltySummary _loyaltyApagado({int saldo = 240}) => LoyaltySummary.fromJson({
      'program': {'enabled': false},
      'client': {'id': 'c1', 'name': 'Nacho Baldovino', 'member_since': '2025-01-10T00:00:00Z'},
      'tier': null,
      'next_tier': null,
      'visits_in_window': 0,
      'grace': null,
      'points': {'balance': saldo, 'expiring_soon_points': 0, 'next_expiry_at': null, 'next_expiry_points': 0},
      'referral': {'enabled': false},
      'tiers': _tiers,
    });

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

List<Override> _overrides({
  required bool conTurno,
  required int saldo,
  LoyaltySummary? loyalty,
}) =>
    [
      authProvider.overrideWith((ref) => _FakeAuth()),
      loyaltyProvider.overrideWith(
        (ref) async => loyalty ?? _loyaltyOro(saldo: saldo),
      ),
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

  // ── Programa de fidelización: tarjeta, categoría, platinum, apagado ─────

  testWidgets('Home — cliente Oro (tarjeta + tira de estado)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(conTurno: true, saldo: 650, loyalty: _loyaltyOro()),
      child: _app(const HomeScreen()),
    ));
    await shot(binding, tester, 'loyalty_01_home_oro');

    // El dorso: anillo de visitas y cuánto falta.
    final ver = find.text('Ver progreso');
    if (ver.evaluate().isNotEmpty) {
      await tester.tap(ver.first, warnIfMissed: false);
      await shot(binding, tester, 'loyalty_02_home_oro_dorso');
    }
  });

  testWidgets('Home — Oro en período de gracia', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(
        conTurno: false,
        saldo: 650,
        loyalty: _loyaltyOro(gracia: true),
      ),
      child: _app(const HomeScreen()),
    ));
    await shot(binding, tester, 'loyalty_03_home_oro_gracia');
  });

  testWidgets('Mi categoría — carrusel y cómo funciona', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(conTurno: false, saldo: 650, loyalty: _loyaltyOro()),
      child: _app(const CategoriaScreen()),
    ));
    await shot(binding, tester, 'loyalty_04_categoria');

    await tester.drag(find.byType(PageView).first, const Offset(-260, 0),
        warnIfMissed: false);
    await shot(binding, tester, 'loyalty_05_categoria_platinum_page');

    await tester.drag(find.byType(ListView).first, const Offset(0, -520),
        warnIfMissed: false);
    await shot(binding, tester, 'loyalty_06_categoria_scroll');
  });

  testWidgets('Mi categoría — en gracia', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(
        conTurno: false,
        saldo: 650,
        loyalty: _loyaltyOro(gracia: true),
      ),
      child: _app(const CategoriaScreen()),
    ));
    await shot(binding, tester, 'loyalty_07_categoria_gracia');
  });

  testWidgets('Home — Platinum (holográfica)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(conTurno: true, saldo: 2400, loyalty: _loyaltyPlatinum()),
      child: _app(const HomeScreen()),
    ));
    await shot(binding, tester, 'loyalty_08_home_platinum');
  });

  testWidgets('Home — programa apagado (vidrio gris)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(conTurno: true, saldo: 240, loyalty: _loyaltyApagado()),
      child: _app(const HomeScreen()),
    ));
    await shot(binding, tester, 'loyalty_09_home_apagado');
  });

  testWidgets('Mi categoría — programa apagado', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(conTurno: false, saldo: 240, loyalty: _loyaltyApagado()),
      child: _app(const CategoriaScreen()),
    ));
    await shot(binding, tester, 'loyalty_10_categoria_apagado');
  });

  testWidgets('Celebración — Plata → Oro', (tester) async {
    final s = _loyaltyOro();
    late BuildContext ctx;
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(conTurno: false, saldo: 650, loyalty: s),
      child: _app(Builder(builder: (c) {
        ctx = c;
        return const HomeScreen();
      })),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    if (!ctx.mounted) return;
    TierUpCelebration.mostrar(
      ctx,
      summary: s,
      desde: s.tierPorCode('plata')!,
      hasta: s.tier!,
    );
    await tester.pump(const Duration(milliseconds: 600));
    await shot(binding, tester, 'loyalty_11_celebracion_morph');
    await shot(binding, tester, 'loyalty_12_celebracion');
  });

  // ── Wizard de turnos: los elementos que llevaban verde ──────────────────
  // No se monta el wizard entero (necesita bootstrap y slots del server): se
  // pintan las piezas que el dueño señaló, que son las que tienen color de
  // estado. Si alguien vuelve a meter verde en un chip o en el CTA, se ve acá.
  testWidgets('Wizard — barra de pasos, días, horarios y CTA', (tester) async {
    final hoy = DateTime.now();
    String d(int n) {
      final x = hoy.add(Duration(days: n));
      return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    }

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MonacoTheme.dark,
      home: Scaffold(
        backgroundColor: MonacoColors.background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              const StepProgress(current: 3, total: 3, label: 'Día y horario'),
              const SizedBox(height: 26),
              const Text(
                '¿Cuándo te viene bien?',
                style: TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: -0),
                child: DayStrip(
                  days: [for (var i = 0; i < 6; i++) d(i)],
                  today: d(0),
                  selected: d(1),
                  enabledDays: const [0, 1, 2, 3, 4, 5, 6],
                  fullDates: {d(3)},
                  unknownDates: const {},
                  onSelect: (_) {},
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: LiquidChip(
                      label: '10:00',
                      expand: true,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      fontSize: 14.5,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LiquidChip(
                      label: '10:45',
                      selected: true,
                      expand: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      fontSize: 14.5,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LiquidChip(
                      label: '11:30',
                      expand: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      fontSize: 14.5,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  LiquidPill(
                    onTap: () {},
                    padding: const EdgeInsets.fromLTRB(14, 13, 16, 13),
                    child: const Text(
                      'Atrás',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LiquidButton(
                      tint: MonacoColors.seleccion,
                      onPressed: () {},
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                      child: const Text(
                        'Confirmar turno',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ));
    await shot(binding, tester, 'wallet_08_wizard');
  });
}
