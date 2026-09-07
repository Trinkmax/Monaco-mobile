import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monaco_mobile/core/api/mobile_api.dart';
import 'package:monaco_mobile/features/senas/data/senas_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `SenasApi` con un `http.Client` falso. Lo que se fija acá es la regla que
/// decide si el cliente paga o no: **sólo `SENA_NO_APLICA` habilita a reservar
/// sin seña**; todo lo demás es un fallo que hay que mostrar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient supabase;

  setUpAll(() async {
    await MobileApi.appVersion();
  });

  setUp(() {
    supabase = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });

  tearDown(() async {
    await supabase.dispose();
  });

  SenasApi buildApi(FutureOr<http.Response> Function(http.Request) handler) {
    return SenasApi(MobileApi(
      supabase,
      client: MockClient((req) async => await handler(req)),
      baseUrl: 'https://api.test',
    ));
  }

  http.Response json(Object body, int status) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

  Future<ResultadoSena> crear(SenasApi api) => api.crear(
        slug: 'parana',
        staffId: 's1',
        date: '2026-09-04',
        startTime: '18:30',
        serviceIds: const ['sv1', 'sv2'],
        durationMinutes: 45,
      );

  const okBody = {
    'ok': true,
    'deposit_id': 'dep-1',
    'init_point': 'https://www.mercadopago.com.ar/checkout/v1/redirect?pref_id=x',
    'amount': 8000,
    'service_total': 16000,
    'resto': 8000,
    'expires_at': '2026-09-04T18:00:00.000-03:00',
    'politica': {
      'titulo': 'Seña \$8.000 ARS',
      'detalle': 'Es el 50%.',
      'cancelacion': 'Cancelás hasta 2 h antes.',
      'reserva': 'El horario se confirma con el pago.',
      'arrepentimiento': null,
    },
  };

  test('pega al endpoint de la sucursal y manda el body de /book + return_to', () async {
    late http.Request visto;
    final api = buildApi((req) {
      visto = req;
      return json(okBody, 200);
    });
    await crear(api);

    expect(visto.method, 'POST');
    expect(visto.url.toString(), 'https://api.test/api/mobile/turnos/parana/sena');
    final body = jsonDecode(visto.body) as Map<String, dynamic>;
    expect(body['staff_id'], 's1');
    expect(body['date'], '2026-09-04');
    expect(body['start_time'], '18:30');
    expect(body['service_ids'], ['sv1', 'sv2']);
    expect(body['duration_minutes'], 45);
    expect(body['return_to'], 'app');
    // Sin nombre pedido, la clave no viaja: el server no tiene que decidir
    // entre "no lo mandó" y "lo mandó vacío".
    expect(body.containsKey('name'), isFalse);
  });

  test('el nombre viaja sólo si tiene 2 caracteres o más', () async {
    late Map<String, dynamic> body;
    final api = buildApi((req) {
      body = jsonDecode(req.body) as Map<String, dynamic>;
      return json(okBody, 200);
    });
    await api.crear(
      slug: 'parana',
      staffId: null,
      date: '2026-09-04',
      startTime: '18:30',
      serviceIds: const ['sv1'],
      durationMinutes: 30,
      name: '  Nacho  ',
    );
    expect(body['name'], 'Nacho');

    await api.crear(
      slug: 'parana',
      staffId: null,
      date: '2026-09-04',
      startTime: '18:30',
      serviceIds: const ['sv1'],
      durationMinutes: 30,
      name: 'x',
    );
    expect(body.containsKey('name'), isFalse);
  });

  test('200 con la intención → SenaRequerida', () async {
    final r = await crear(buildApi((_) => json(okBody, 200)));
    expect(r, isA<SenaRequerida>());
    expect((r as SenaRequerida).intencion.monto, 8000);
  });

  test('SENA_NO_APLICA con 200 y ok:false → se reserva sin seña', () async {
    final r = await crear(buildApi(
      (_) => json({'ok': false, 'code': 'SENA_NO_APLICA', 'message': 'no'}, 200),
    ));
    expect(r, isA<SenaNoAplica>());
  });

  test('SENA_NO_APLICA con 409 también → se reserva sin seña', () async {
    // El route handler puede contestarlo de las dos formas; los dos caminos
    // tienen que terminar igual o la app cobra donde no corresponde.
    final r = await crear(buildApi(
      (_) => json({'error': 'SENA_NO_APLICA', 'message': 'no'}, 409),
    ));
    expect(r, isA<SenaNoAplica>());
  });

  test('un fallo de Mercado Pago NO habilita a reservar sin pagar', () async {
    // Si esto devolviera SenaNoAplica, cada hipo de MP regalaría un turno.
    final r = await crear(buildApi(
      (_) => json({'error': 'MP_ERROR', 'message': 'boom'}, 502),
    ));
    expect(r, isA<SenaFallo>());
    expect((r as SenaFallo).code, 'MP_ERROR');
  });

  test('un 200 sin init_point es un fallo, no un éxito', () async {
    final r = await crear(buildApi(
      (_) => json({...okBody, 'init_point': ''}, 200),
    ));
    expect(r, isA<SenaFallo>());
  });

  test('SLOT_TAKEN llega tipado para poder recargar la grilla', () async {
    final r = await crear(buildApi(
      (_) => json({'error': 'SLOT_TAKEN', 'message': 'tomado'}, 409),
    ));
    expect((r as SenaFallo).grillaVieja, isTrue);
  });

  test('estado() lee GET /api/mobile/senas/<id>', () async {
    late Uri url;
    final api = buildApi((req) {
      url = req.url;
      return json({
        'ok': true,
        'deposit_id': 'dep-1',
        'status': 'pagada',
        'amount': 8000,
        'resto': 8000,
        'appointment': {
          'id': 'ap-1',
          'appointment_date': '2026-09-04',
          'start_time': '18:30:00',
          'branch_name': 'Paraná',
        },
        'seguir_esperando': false,
      }, 200);
    });
    final e = await api.estado('dep-1');
    expect(url.path, '/api/mobile/senas/dep-1');
    expect(e.estado.turnoConfirmado, isTrue);
    expect(e.turno?.sucursal, 'Paraná');
  });
}
