import 'dart:async';
import 'dart:convert';
import 'dart:io';

// fake_async llega transitivamente con flutter_test; no está en pubspec.yaml
// (lo maneja el coordinador).
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monaco_mobile/core/api/mobile_api.dart';
import 'package:monaco_mobile/core/utils/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tests del cliente HTTP hacia `/api/mobile/*` con un `http.Client` falso.
/// No hay Supabase inicializado: el `SupabaseClient` se construye a mano sin
/// sesión, así que las requests salen SIN `Authorization` (eso también se
/// verifica) y nada toca la red.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient supabase;

  setUpAll(() async {
    // PackageInfo no tiene plugin en tests: MobileApi cae en 'unknown' y lo
    // cachea. Lo precalentamos acá para que el test de timeout (fakeAsync)
    // no dependa de una respuesta del canal de plataforma.
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

  MobileApi buildApi(
    FutureOr<http.Response> Function(http.Request) handler, {
    String baseUrl = 'https://api.test',
  }) {
    return MobileApi(
      supabase,
      client: MockClient((req) async => await handler(req)),
      baseUrl: baseUrl,
    );
  }

  http.Response json(Object body, int status) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

  group('request', () {
    test('GET arma la URL con base + path + query y manda los headers de app',
        () async {
      http.Request? captured;
      final api = buildApi((req) {
        captured = req;
        return json({'ok': true}, 200);
      });

      final res = await api.getJson(
        '/api/mobile/turnos/rondeau/slots',
        query: {'date': '2026-08-21', 'service_ids': 'a,b'},
      );

      expect(res, {'ok': true});
      expect(captured, isNotNull);
      expect(captured!.method, 'GET');
      expect(captured!.url.toString(),
          'https://api.test/api/mobile/turnos/rondeau/slots?date=2026-08-21&service_ids=a%2Cb');
      expect(captured!.headers['Accept'], 'application/json');
      expect(captured!.headers['Content-Type'], startsWith('application/json'));
      expect(captured!.headers['X-App-Platform'], anyOf('ios', 'android'));
      expect(captured!.headers['X-App-Version'], isNotEmpty);
      // Sin sesión no viaja Bearer: el server contesta 401 y la app lo trata.
      expect(captured!.headers.containsKey('Authorization'), isFalse);
    });

    test('acepta path sin barra inicial y base con barra final', () async {
      http.Request? captured;
      final api = buildApi(
        (req) {
          captured = req;
          return json({}, 200);
        },
        baseUrl: 'https://api.test/',
      );
      await api.getJson('api/mobile/me');
      expect(captured!.url.toString(), 'https://api.test/api/mobile/me');
    });

    test('query vacía no deja un "?" colgado', () async {
      http.Request? captured;
      final api = buildApi((req) {
        captured = req;
        return json({}, 200);
      });
      await api.getJson('/api/mobile/me', query: {});
      expect(captured!.url.toString(), 'https://api.test/api/mobile/me');
    });

    test('POST serializa el body como JSON', () async {
      http.Request? captured;
      final api = buildApi((req) {
        captured = req;
        return json({'ok': true, 'name': 'Nacho'}, 200);
      });
      final res = await api.postJson('/api/mobile/me', {'name': 'Nacho'});
      expect(res['name'], 'Nacho');
      expect(captured!.method, 'POST');
      expect(jsonDecode(captured!.body), {'name': 'Nacho'});
    });

    test('DELETE también manda body JSON (baja de token push)', () async {
      http.Request? captured;
      final api = buildApi((req) {
        captured = req;
        return json({'ok': true}, 200);
      });
      await api.deleteJson('/api/mobile/push/token', {'device_id': 'dev-1'});
      expect(captured!.method, 'DELETE');
      expect(jsonDecode(captured!.body), {'device_id': 'dev-1'});
    });
  });

  group('respuestas 2xx', () {
    test('body vacío (204) devuelve un mapa vacío', () async {
      final api = buildApi((_) => http.Response('', 204));
      expect(await api.getJson('/x'), isEmpty);
    });

    test('un JSON que no es objeto se envuelve en {data: ...}', () async {
      final api = buildApi((_) => json([1, 2, 3], 200));
      expect(await api.getJson('/x'), {
        'data': [1, 2, 3]
      });
    });

    test('un 2xx con body no-JSON es BAD_RESPONSE', () async {
      final api = buildApi((_) => http.Response('<html>ok</html>', 200));
      await expectLater(
        api.getJson('/x'),
        throwsA(isA<MobileApiException>()
            .having((e) => e.code, 'code', 'BAD_RESPONSE')
            .having((e) => e.status, 'status', 200)),
      );
    });
  });

  group('errores del server', () {
    test('4xx con {error, message} se tipa con el código del server', () async {
      final api = buildApi((_) => json(
            {'error': 'SLOT_TAKEN', 'message': 'Ese horario ya no está disponible.'},
            409,
          ));
      await expectLater(
        api.postJson('/api/mobile/turnos/rondeau/book', {}),
        throwsA(isA<MobileApiException>()
            .having((e) => e.code, 'code', 'SLOT_TAKEN')
            .having((e) => e.message, 'message',
                'Ese horario ya no está disponible.')
            .having((e) => e.status, 'status', 409)
            .having((e) => e.body?['error'], 'body.error', 'SLOT_TAKEN')
            .having((e) => e.isNetwork, 'isNetwork', isFalse)
            .having((e) => e.isUnauthenticated, 'isUnauthenticated', isFalse)),
      );
    });

    test('401 es isUnauthenticated aunque el body no diga UNAUTHENTICATED',
        () async {
      final api = buildApi((_) => json({'message': 'expirado'}, 401));
      await expectLater(
        api.getJson('/api/mobile/me'),
        throwsA(isA<MobileApiException>()
            .having((e) => e.isUnauthenticated, 'isUnauthenticated', isTrue)
            .having((e) => e.code, 'code', 'HTTP_401')
            .having((e) => e.message, 'message', 'expirado')),
      );
    });

    test('UNAUTHENTICATED por código también cuenta', () {
      const e = MobileApiException('UNAUTHENTICATED', 'Iniciá sesión de nuevo.');
      expect(e.isUnauthenticated, isTrue);
      expect(e.status, isNull);
    });

    test('429 RATE_LIMITED conserva el mensaje humano', () async {
      final api = buildApi((_) => json(
            {'error': 'RATE_LIMITED', 'message': 'Demasiados intentos.'},
            429,
          ));
      await expectLater(
        api.getJson('/x'),
        throwsA(isA<MobileApiException>()
            .having((e) => e.code, 'code', 'RATE_LIMITED')
            .having((e) => e.status, 'status', 429)),
      );
    });

    test('error sin "message" pero con "error" string usa el error como mensaje',
        () async {
      final api = buildApi((_) => json({'error': 'NOT_FOUND'}, 404));
      await expectLater(
        api.getJson('/x'),
        throwsA(isA<MobileApiException>()
            .having((e) => e.code, 'code', 'NOT_FOUND')
            .having((e) => e.message, 'message', 'NOT_FOUND')),
      );
    });

    test('error sin JSON útil cae en HTTP_<status> con mensaje genérico',
        () async {
      final api = buildApi((_) => json({}, 503));
      await expectLater(
        api.getJson('/x'),
        throwsA(isA<MobileApiException>()
            .having((e) => e.code, 'code', 'HTTP_503')
            .having((e) => e.message, 'message', contains('503'))),
      );
    });

    test('5xx con HTML (Vercel caído) es BAD_RESPONSE con el status', () async {
      final api = buildApi((_) => http.Response('<html>502</html>', 502));
      await expectLater(
        api.getJson('/x'),
        throwsA(isA<MobileApiException>()
            .having((e) => e.code, 'code', 'BAD_RESPONSE')
            .having((e) => e.status, 'status', 502)),
      );
    });
  });

  group('errores de red', () {
    test('ClientException → NETWORK', () async {
      final api = buildApi((_) => throw http.ClientException('conexión rechazada'));
      await expectLater(
        api.getJson('/x'),
        throwsA(isA<MobileApiException>()
            .having((e) => e.code, 'code', 'NETWORK')
            .having((e) => e.isNetwork, 'isNetwork', isTrue)
            .having((e) => e.message, 'message', contains('Sin conexión'))),
      );
    });

    test('SocketException → NETWORK', () async {
      final api = buildApi((_) => throw const SocketException('host no resuelve'));
      await expectLater(
        api.getJson('/x'),
        throwsA(isA<MobileApiException>()
            .having((e) => e.code, 'code', 'NETWORK')
            .having((e) => e.isNetwork, 'isNetwork', isTrue)),
      );
    });

    test('HandshakeException → NETWORK (conexión insegura)', () async {
      final api = buildApi((_) => throw const HandshakeException('cert'));
      await expectLater(
        api.getJson('/x'),
        throwsA(isA<MobileApiException>()
            .having((e) => e.code, 'code', 'NETWORK')
            .having((e) => e.message, 'message', contains('insegura'))),
      );
    });

    test('el mensaje NO lleva el texto técnico: eso va en `detail`', () async {
      // `e.message` se imprime tal cual en el wizard de reserva, en la grilla
      // de horarios y en el toast de cancelar. Un reviewer probando en modo
      // avión no puede ver «Failed host lookup: 'monacobarber.vercel.app'».
      final api = buildApi(
        (_) => throw const SocketException(
          "Failed host lookup: 'monacobarber.vercel.app'",
        ),
      );
      try {
        await api.getJson('/x');
        fail('tenía que tirar');
      } on MobileApiException catch (e) {
        expect(e.message, 'Sin conexión. Revisá tu internet e intentá de nuevo.');
        expect(e.message, isNot(contains('Failed host lookup')));
        expect(e.message, isNot(contains(':')));
        expect(e.detail, contains('Failed host lookup'));
        // El detalle técnico sí queda en el log.
        expect(e.toString(), contains('Failed host lookup'));
      }
    });

    test('una request que no responde corta en apiTimeout con TIMEOUT', () {
      fakeAsync((async) {
        final api = buildApi((_) => Completer<http.Response>().future);
        Object? error;
        api.getJson('/x').then<void>(
          (_) {},
          onError: (Object e) {
            error = e;
          },
        );

        async.elapse(AppConstants.apiTimeout - const Duration(seconds: 1));
        expect(error, isNull, reason: 'todavía no venció el timeout');

        async.elapse(const Duration(seconds: 2));
        expect(error, isA<MobileApiException>());
        final e = error! as MobileApiException;
        expect(e.code, 'TIMEOUT');
        expect(e.isNetwork, isTrue);
      });
    });
  });

  group('sesión zombi', () {
    test('un 401 avisa una vez y la excepción igual llega a quien llamó',
        () async {
      final avisos = <MobileApiException>[];
      final api = MobileApi(
        supabase,
        client: MockClient((_) async => json({'message': 'expirado'}, 401)),
        baseUrl: 'https://api.test',
        onSesionInvalida: avisos.add,
      );

      await expectLater(
        api.getJson('/api/mobile/me'),
        throwsA(isA<MobileApiException>()),
      );
      expect(avisos, hasLength(1));
      expect(avisos.single.esSesionMuerta, isTrue);
    });

    test('NO_CLIENT también avisa: la ficha se borró o se fusionó', () async {
      // El JWT sigue siendo válido, así que Supabase no emite `signedOut` y sin
      // este aviso la app falla en TODAS las pantallas sin ofrecer salida.
      final avisos = <MobileApiException>[];
      final api = MobileApi(
        supabase,
        client: MockClient(
          (_) async => json({'error': 'NO_CLIENT', 'message': 'sin ficha'}, 403),
        ),
        baseUrl: 'https://api.test',
        onSesionInvalida: avisos.add,
      );

      await expectLater(api.getJson('/x'), throwsA(isA<MobileApiException>()));
      expect(avisos.single.code, 'NO_CLIENT');
    });

    test('un error común NO cierra la sesión', () async {
      final avisos = <MobileApiException>[];
      final api = MobileApi(
        supabase,
        client: MockClient(
          (_) async => json({'error': 'SLOT_TAKEN'}, 409),
        ),
        baseUrl: 'https://api.test',
        onSesionInvalida: avisos.add,
      );

      await expectLater(api.getJson('/x'), throwsA(isA<MobileApiException>()));
      expect(avisos, isEmpty);
    });

    test('una caída de red tampoco: la sesión puede estar perfecta', () async {
      final avisos = <MobileApiException>[];
      final api = MobileApi(
        supabase,
        client: MockClient((_) async => throw const SocketException('sin red')),
        baseUrl: 'https://api.test',
        onSesionInvalida: avisos.add,
      );

      await expectLater(api.getJson('/x'), throwsA(isA<MobileApiException>()));
      expect(avisos, isEmpty);
    });
  });

  test('toString es legible en logs', () {
    const e = MobileApiException('SLOT_TAKEN', 'ocupado', status: 409);
    expect(e.toString(), 'MobileApiException(SLOT_TAKEN, 409): ocupado');
  });
}
