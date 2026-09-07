import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/api/mobile_api.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/features/appointments/providers/appointments_provider.dart';

import '../data/sena_pendiente_store.dart';
import '../data/senas_api.dart';

final senaPendienteStoreProvider = Provider<SenaPendienteStore>((ref) {
  return const SenaPendienteStore();
});

/// La seña que quedó a medio pagar, si sigue vigente. La leen el cartel de
/// "Mis turnos" y el del Home para poder retomarla.
final senaPendienteProvider = FutureProvider.autoDispose<SenaPendiente?>((ref) {
  return ref.watch(senaPendienteStoreProvider).leer();
});

/// Estado de la pantalla "Confirmando tu pago".
class SenaEstadoState {
  final SenaEstado? estado;

  /// Primera carga (todavía no sabemos nada).
  final bool cargando;

  /// Hay una consulta en vuelo sobre un estado que ya conocemos.
  final bool revisando;

  /// No se pudo leer el estado. **No es lo mismo que "el pago falló"**: la
  /// pantalla lo dice con esas palabras y ofrece reintentar.
  final String? errorDeLectura;

  /// Se agotaron los 3 minutos de espera automática.
  final bool esperaAgotada;

  const SenaEstadoState({
    this.estado,
    this.cargando = true,
    this.revisando = false,
    this.errorDeLectura,
    this.esperaAgotada = false,
  });

  SenaEstadoState copyWith({
    SenaEstado? estado,
    bool? cargando,
    bool? revisando,
    Object? errorDeLectura = _sinCambio,
    bool? esperaAgotada,
  }) {
    return SenaEstadoState(
      estado: estado ?? this.estado,
      cargando: cargando ?? this.cargando,
      revisando: revisando ?? this.revisando,
      errorDeLectura: errorDeLectura == _sinCambio
          ? this.errorDeLectura
          : errorDeLectura as String?,
      esperaAgotada: esperaAgotada ?? this.esperaAgotada,
    );
  }
}

const _sinCambio = Object();

final senaEstadoProvider = StateNotifierProvider.autoDispose
    .family<SenaEstadoController, SenaEstadoState, String>((ref, depositId) {
  return SenaEstadoController(ref, depositId);
});

/// Sigue una seña con **dos fuentes**, porque ninguna de las dos alcanza sola:
///
/// - **Realtime de Supabase** sobre `booking_deposits` filtrado por esta fila
///   (la mig 207 le dio al cliente policy de SELECT sobre lo suyo y metió la
///   tabla en la publication). Llega en cuanto el webhook escribe, pero un
///   WebSocket puede no conectar —red de datos mala, la app volviendo de
///   segundo plano— y ahí no avisa nunca.
/// - **Polling cada 3 s** contra `GET /api/mobile/senas/<id>`, que es HTTP
///   simple y funciona donde el WebSocket no. Corta a los 3 minutos: seguir
///   golpeando media hora no acredita nada y gasta batería.
///
/// El evento de Realtime **no se usa como dato**, se usa como aviso: trae la
/// fila cruda, sin el nombre del barbero ni el de la sucursal, y sin el motivo
/// del rechazo ya traducido. Cuando llega, se vuelve a preguntar al endpoint,
/// que es el que arma la respuesta completa.
class SenaEstadoController extends StateNotifier<SenaEstadoState> {
  final Ref _ref;
  final String depositId;

  static const _intervalo = Duration(seconds: 3);
  static const _limiteDeEspera = Duration(minutes: 3);

  Timer? _poll;
  StreamSubscription<List<Map<String, dynamic>>>? _realtime;
  DateTime? _desde;
  bool _consultando = false;

  SenaEstadoController(this._ref, this.depositId) : super(const SenaEstadoState()) {
    _desde = DateTime.now();
    unawaited(_consultar(primera: true));
    _escucharRealtime();
  }

  SenasApi get _api => _ref.read(senasApiProvider);

  void _escucharRealtime() {
    try {
      _realtime = _ref
          .read(supabaseClientProvider)
          .from('booking_deposits')
          .stream(primaryKey: ['id'])
          .eq('id', depositId)
          .listen(
            (rows) {
              if (rows.isEmpty) return;
              // Sólo un disparador: el dato bueno lo arma el endpoint.
              unawaited(_consultar());
            },
            onError: (Object e) {
              // Que el WebSocket no conecte no es un error para el cliente:
              // el polling sigue andando y él no tiene por qué enterarse.
              debugPrint('[sena] realtime $depositId: $e');
            },
          );
    } catch (e) {
      debugPrint('[sena] no se pudo suscribir a realtime: $e');
    }
  }

  void _programarPoll() {
    _poll?.cancel();
    final estado = state.estado;
    if (estado != null && !estado.seguirEsperando) return;
    final desde = _desde;
    if (desde != null && DateTime.now().difference(desde) >= _limiteDeEspera) {
      state = state.copyWith(esperaAgotada: true);
      return;
    }
    _poll = Timer(_intervalo, () => unawaited(_consultar()));
  }

  /// Una consulta al endpoint. Nunca hay dos en vuelo: un `revisarAhora` en
  /// medio de un tick del timer duplicaría requests sin acelerar nada.
  Future<void> _consultar({bool primera = false}) async {
    if (!mounted || _consultando) return;
    _consultando = true;
    if (!primera) state = state.copyWith(revisando: true);
    try {
      final estado = await _api.estado(depositId);
      if (!mounted) return;
      state = state.copyWith(
        estado: estado,
        cargando: false,
        revisando: false,
        errorDeLectura: null,
      );
      if (estado.estado.turnoConfirmado) {
        // El turno nació del webhook, no de esta app: si no invalidamos, "Mis
        // turnos" y el Home siguen mostrando la lista de antes de pagar.
        invalidateAppointments(_ref, appointmentId: estado.turno?.id);
      }
      if (estado.estado.terminal) {
        _poll?.cancel();
        // Un estado terminal no vuelve: se suelta el WebSocket y se borra la
        // marca local para que el cartel de "retomá tu pago" no quede colgado.
        unawaited(_realtime?.cancel());
        _realtime = null;
        unawaited(_ref.read(senaPendienteStoreProvider).limpiarSiEs(depositId));
      }
    } on MobileApiException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        cargando: false,
        revisando: false,
        // Con un estado ya conocido, un fallo de lectura no lo pisa: seguimos
        // mostrando lo último cierto y avisamos abajo.
        errorDeLectura: e.isNetwork
            ? 'No pudimos revisar el estado del pago. Revisá tu conexión.'
            : e.message,
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('[sena] estado $depositId falló: $e');
      state = state.copyWith(
        cargando: false,
        revisando: false,
        errorDeLectura: 'No pudimos revisar el estado del pago. Probá de nuevo.',
      );
    } finally {
      _consultando = false;
      if (mounted) _programarPoll();
    }
  }

  /// "Ya pagué, revisá de nuevo": vuelve a abrir la ventana de espera. El
  /// cliente que toca ese botón está diciendo algo que nosotros no sabemos —que
  /// el pago ya salió— y merece que volvamos a intentar.
  Future<void> revisarAhora() async {
    _desde = DateTime.now();
    state = state.copyWith(esperaAgotada: false, errorDeLectura: null);
    await _consultar();
  }

  @override
  void dispose() {
    _poll?.cancel();
    unawaited(_realtime?.cancel());
    super.dispose();
  }
}
