// Vista previa VISUAL de la SEÑA (Mercado Pago), sin login, sin red y sin
// tocar Mercado Pago:
//
//   QA_SHOTS_DIR=build/sena-shots flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/sena_preview_test.dart -d <udid-simulador>
//
// Pinta la hoja de confirmación con la política y las cinco caras de la
// pantalla "Confirmando tu pago" con datos fijos. Es el mismo banco de pruebas
// que `wallet_preview_test.dart`: los overflows salen de acá y no de
// `flutter test`, porque en un widget test una tarjeta sin constraint de alto
// crece lo que necesita y nunca desborda.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/features/senas/data/sena_models.dart';
import 'package:monaco_mobile/features/senas/data/sena_pendiente_store.dart';
import 'package:monaco_mobile/features/senas/presentation/screens/pago_sena_screen.dart';
import 'package:monaco_mobile/features/senas/presentation/widgets/sena_confirm_sheet.dart';
import 'package:monaco_mobile/features/senas/presentation/widgets/sena_pendiente_banner.dart';
import 'package:monaco_mobile/features/senas/providers/sena_estado_provider.dart';

// ── Datos de muestra ───────────────────────────────────────────────────────

const _linkFalso = 'https://www.mercadopago.com.ar/checkout/v1/redirect?pref_id=demo';

final _intencion = SenaIntencion.fromJson({
  'deposit_id': 'dep-demo',
  'init_point': _linkFalso,
  'amount': 8000,
  'service_total': 16000,
  'resto': 8000,
  'expires_at': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
  'politica': {
    'titulo': 'Seña \$8.000 ARS',
    'detalle': 'Es el 50 % de Corte + Barba. Los \$8.000 restantes los pagás en el local.',
    'reserva': 'El horario queda reservado recién cuando se acredita el pago. '
        'Si otra persona lo toma antes, te devolvemos la seña completa.',
    'cancelacion': 'Cancelando con más de 2 horas de anticipación, la seña te '
        'queda como crédito para tu próximo turno. Si no venís o cancelás sobre '
        'la hora, la seña se pierde.',
    'arrepentimiento': 'Tenés 10 días corridos para arrepentirte de la compra y '
        'pedir la devolución, salvo que el servicio ya se haya prestado.',
  },
});

const _resumen = ResumenTurnoSena(
  sucursal: 'Paraná',
  servicios: 'Corte + Barba',
  fecha: '2026-09-04',
  hora: '18:30',
  barbero: 'Fabri',
);

SenaEstado _estado(
  String status, {
  bool conTurno = false,
  String? mensaje,
  bool? seguir,
}) =>
    SenaEstado.fromJson({
      'deposit_id': 'dep-demo',
      'status': status,
      'amount': 8000,
      'resto': 8000,
      'mensaje': mensaje,
      'seguir_esperando': ?seguir,
      'appointment': conTurno
          ? {
              'id': 'ap-demo',
              'appointment_date': '2026-09-04',
              'start_time': '18:30:00',
              'barber_name': 'Fabri',
              'branch_name': 'Paraná',
              'service_names': 'Corte + Barba',
            }
          : null,
    });

/// Controller de mentira: el real sale a la red y abre un WebSocket en el
/// constructor.
class _FakeSenaCtrl extends StateNotifier<SenaEstadoState>
    implements SenaEstadoController {
  _FakeSenaCtrl(super.state);

  @override
  Future<void> revisarAhora() async {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

List<Override> _overrides(SenaEstadoState estado) => [
      senaEstadoProvider.overrideWith((ref, id) => _FakeSenaCtrl(estado)),
    ];

Widget _app(Widget home, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: MonacoTheme.dark,
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => home),
          // Destinos de los botones, para que tocar no rompa el test.
          GoRoute(
            path: '/turnos',
            builder: (_, _) => const Scaffold(
              backgroundColor: MonacoColors.background,
              body: Center(child: Text('Mis turnos')),
            ),
          ),
          GoRoute(
            path: '/turnos/reservar',
            builder: (_, _) => const Scaffold(
              backgroundColor: MonacoColors.background,
              body: Center(child: Text('Reservar')),
            ),
          ),
          GoRoute(
            path: '/pago/:id',
            builder: (_, _) => const Scaffold(
              backgroundColor: MonacoColors.background,
              body: Center(child: Text('Pago')),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> shot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name, {
  int frames = 8,
}) async {
  // La pantalla de espera tiene un latido en loop: `pumpAndSettle` no termina.
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

  testWidgets('Hoja de confirmación de la seña', (tester) async {
    await tester.pumpWidget(_app(
      Builder(
        builder: (ctx) => Scaffold(
          backgroundColor: MonacoColors.background,
          body: Center(
            child: TextButton(
              onPressed: () => mostrarHojaDeSena(
                ctx,
                intencion: _intencion,
                resumen: _resumen,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await shot(binding, tester, 'sena_01_hoja');
  });

  testWidgets('Confirmando tu pago — esperando', (tester) async {
    await tester.pumpWidget(_app(
      const PagoSenaScreen(depositId: 'dep-demo', initPoint: _linkFalso),
      overrides: _overrides(SenaEstadoState(
        estado: _estado('iniciada'),
        cargando: false,
      )),
    ));
    await shot(binding, tester, 'sena_02_esperando');
  });

  testWidgets('Confirmando tu pago — la espera se agotó', (tester) async {
    await tester.pumpWidget(_app(
      const PagoSenaScreen(depositId: 'dep-demo', initPoint: _linkFalso),
      overrides: _overrides(SenaEstadoState(
        estado: _estado('iniciada'),
        cargando: false,
        esperaAgotada: true,
        errorDeLectura: 'No pudimos revisar el estado del pago. Revisá tu conexión.',
      )),
    ));
    await shot(binding, tester, 'sena_03_espera_agotada');
  });

  testWidgets('Turno confirmado — velo verde y resultado', (tester) async {
    await tester.pumpWidget(_app(
      const PagoSenaScreen(depositId: 'dep-demo', initPoint: _linkFalso),
      overrides: _overrides(SenaEstadoState(
        estado: _estado('pagada', conTurno: true),
        cargando: false,
      )),
    ));
    await shot(binding, tester, 'sena_04_velo_verde', frames: 4);
    // El velo dura 2,4 s: se lo deja terminar para ver la pantalla de abajo.
    await shot(binding, tester, 'sena_05_confirmado', frames: 16);
  });

  testWidgets('Sin cupo — le ganaron de mano y se devolvió la seña', (tester) async {
    await tester.pumpWidget(_app(
      const PagoSenaScreen(depositId: 'dep-demo', initPoint: _linkFalso),
      overrides: _overrides(SenaEstadoState(
        estado: _estado('sin_cupo', seguir: false),
        cargando: false,
      )),
    ));
    await shot(binding, tester, 'sena_06_sin_cupo');
  });

  testWidgets('Pago rechazado — con el motivo real', (tester) async {
    await tester.pumpWidget(_app(
      const PagoSenaScreen(depositId: 'dep-demo', initPoint: _linkFalso),
      overrides: _overrides(SenaEstadoState(
        estado: _estado(
          'rechazada',
          seguir: false,
          mensaje: 'La tarjeta no tenía fondos suficientes. '
              'Probá con otra o con dinero en cuenta.',
        ),
        cargando: false,
      )),
    ));
    await shot(binding, tester, 'sena_07_rechazado');
  });

  testWidgets('Link vencido', (tester) async {
    await tester.pumpWidget(_app(
      const PagoSenaScreen(depositId: 'dep-demo', initPoint: _linkFalso),
      overrides: _overrides(SenaEstadoState(
        estado: _estado('expirada', seguir: false),
        cargando: false,
      )),
    ));
    await shot(binding, tester, 'sena_08_vencido');
  });

  testWidgets('Cartel de "retomá tu pago"', (tester) async {
    await tester.pumpWidget(_app(
      Scaffold(
        backgroundColor: MonacoColors.background,
        // Column con `min`: en el Home y en Mis turnos el cartel vive dentro
        // de una columna que le da su alto natural. Sin esto, el body le pasa
        // constraints de pantalla completa y la lámina se estira entera.
        body: const Padding(
          padding: EdgeInsets.fromLTRB(20, 80, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [SenaPendienteBanner()],
          ),
        ),
      ),
      overrides: [
        senaPendienteProvider.overrideWith((ref) async => SenaPendiente(
              depositId: 'dep-demo',
              resumen: 'Corte + Barba · Jue 4 sep 18:30',
              monto: 8000,
              initPoint: _linkFalso,
              venceEn: DateTime.now().toUtc().add(const Duration(minutes: 20)),
              creadaEn: DateTime.now().toUtc(),
            )),
      ],
    ));
    await shot(binding, tester, 'sena_09_banner');
  });
}
