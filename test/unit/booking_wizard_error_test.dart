import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid_states.dart';
import 'package:monaco_mobile/core/api/mobile_api.dart';
import 'package:monaco_mobile/features/appointments/data/booking_api.dart';
import 'package:monaco_mobile/features/appointments/providers/booking_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// La pantalla de error del wizard.
///
/// `LiquidErrorState` decide ícono y título olfateando la forma CRUDA de la
/// excepción (`isNetworkError`), así que el estado tiene que guardar la
/// excepción ADEMÁS del mensaje ya traducido: con el texto solo, el cliente en
/// modo avión leía "Algo salió mal" con el ícono genérico en vez de
/// "Sin conexión" con el wifi tachado.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient supabase;

  setUpAll(() async {
    // PackageInfo no tiene plugin en tests: se precalienta el cache para que
    // `MobileApi` no dependa del canal de plataforma.
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

  /// Arranca el wizard con un slug de deep-link (va directo al bootstrap) y
  /// devuelve el estado cuando la carga ya falló.
  Future<BookingWizardState> estadoTrasFallar(
    Future<http.Response> Function() responder,
  ) async {
    final api = MobileApi(
      supabase,
      client: MockClient((_) => responder()),
      baseUrl: 'https://api.test',
    );
    final container = ProviderContainer(
      overrides: [bookingApiProvider.overrideWithValue(BookingApi(api))],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      bookingWizardProvider('rondeau'),
      (_, _) {},
      fireImmediately: true,
    );
    await pumpEventQueue();
    return sub.read();
  }

  test('sin internet: el estado guarda la excepción, no sólo su mensaje',
      () async {
    final state = await estadoTrasFallar(
      () async => throw const SocketException("Failed host lookup: 'api.test'"),
    );

    expect(state.phase, WizardPhase.failed);
    expect(state.loadError, 'Sin conexión. Revisá tu internet e intentá de nuevo.');

    // Esto es lo que mira la pantalla para dibujar wifi + "Sin conexión".
    expect(LiquidErrorState.isNetworkError(state.loadErrorCausa), isTrue);
    // Y esto es por qué no alcanza con el mensaje: ya viene traducido.
    expect(LiquidErrorState.isNetworkError(state.loadError), isFalse);
  });

  test('un fallo del server NO se disfraza de falta de conexión', () async {
    final state = await estadoTrasFallar(
      () async => http.Response(
        '{"error":"SERVER_ERROR","message":"Algo salió mal (500)."}',
        500,
        headers: {'content-type': 'application/json'},
      ),
    );

    expect(state.phase, WizardPhase.failed);
    expect(state.loadError, 'Algo salió mal (500).');
    expect(LiquidErrorState.isNetworkError(state.loadErrorCausa), isFalse);
  });

  test('reintentar limpia la causa del intento anterior', () {
    const previo = BookingWizardState(
      phase: WizardPhase.failed,
      loadError: 'Sin conexión. Revisá tu internet e intentá de nuevo.',
      loadErrorCausa: SocketException('Failed host lookup'),
    );

    final limpio = previo.copyWith(
      phase: WizardPhase.loading,
      loadError: null,
      loadErrorCausa: null,
    );

    expect(limpio.loadError, isNull);
    expect(limpio.loadErrorCausa, isNull);
    // Y sin pasarla, la causa sobrevive al `copyWith` (centinela `_unset`).
    expect(previo.copyWith(phase: WizardPhase.loading).loadErrorCausa, isNotNull);
  });
}
