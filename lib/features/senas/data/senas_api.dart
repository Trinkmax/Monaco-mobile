import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/api/mobile_api.dart';
import 'package:monaco_mobile/core/utils/constants.dart';

import 'sena_models.dart';

export 'sena_models.dart';

final senasApiProvider = Provider<SenasApi>((ref) {
  return SenasApi(ref.watch(mobileApiProvider));
});

/// Cliente de los dos endpoints de la seña. Igual que el resto de la API
/// mobile, la identidad sale del JWT: acá no viaja `client_id` ni teléfono.
///
/// **El motor de la seña vive en el dashboard** (`src/lib/senas/motor.ts`): la
/// app no calcula el monto, no decide si corresponde y no crea el turno. Sólo
/// pregunta y muestra.
class SenasApi {
  final MobileApi _api;
  const SenasApi(this._api);

  /// Pide la intención de seña para un horario. Se llama ANTES de `/book`.
  ///
  /// Devuelve [SenaNoAplica] cuando la sucursal no cobra seña por este canal
  /// —el camino de las cuatro sucursales de Monaco hoy— y ahí el llamador
  /// sigue por `POST /book` como siempre.
  ///
  /// Cualquier OTRO error devuelve [SenaFallo] y **no** habilita a reservar sin
  /// pagar: si la sucursal exige seña y Mercado Pago no responde, caer al
  /// `/book` normal sería regalar turnos cada vez que MP tiene un hipo.
  Future<ResultadoSena> crear({
    required String slug,
    required String? staffId,
    required String date,
    required String startTime,
    required List<String> serviceIds,
    required int durationMinutes,
    String? name,
  }) async {
    try {
      final json = await _api.postJson(
        '/api/mobile/turnos/${Uri.encodeComponent(slug)}/sena',
        {
          'staff_id': staffId,
          'date': date,
          'start_time': startTime,
          'service_ids': serviceIds,
          'duration_minutes': durationMinutes,
          // Mismo campo que `/book`: es la ÚNICA oportunidad de mandar el
          // nombre de un cliente que todavía no lo tiene cargado. Con seña, el
          // turno lo crea el webhook y la app ya no vuelve a hablar con
          // `/book`; sin esto, ese turno queda a nombre del teléfono.
          if (name != null && name.trim().length >= 2) 'name': name.trim(),
          // A dónde vuelve el cliente cuando Mercado Pago termina: el server
          // arma la back_url https y esa página rebota al deep link de la app.
          'return_to': 'app',
        },
        timeout: AppConstants.senaTimeout,
      );
      return _leer(json);
    } on MobileApiException catch (e) {
      // El contrato admite devolver el rechazo con 200 y `ok:false`, pero
      // también con 409/429. Los dos caminos tienen que terminar igual.
      if (e.code == 'SENA_NO_APLICA') return const SenaNoAplica();
      return SenaFallo(e.code, mensajeDeSena(e.code, e.message));
    } catch (e) {
      debugPrint('[sena] crear falló: $e');
      return const SenaFallo(
        'INTERNAL',
        'No pudimos abrir el pago de la seña. Probá de nuevo en un momento.',
      );
    }
  }

  ResultadoSena _leer(Map<String, dynamic> json) {
    if (json['ok'] == false) {
      final code = json['code']?.toString() ?? 'INTERNAL';
      if (code == 'SENA_NO_APLICA') return const SenaNoAplica();
      return SenaFallo(code, mensajeDeSena(code, json['message']?.toString()));
    }
    final intencion = SenaIntencion.fromJson(json);
    if (!intencion.usable) {
      // Un 200 sin link de pago no es éxito. Sin este guard, la app abriría
      // una URL vacía y dejaría al cliente en una pantalla que espera para
      // siempre un pago que nunca se pudo hacer.
      debugPrint('[sena] respuesta 200 sin init_point usable: $json');
      return const SenaFallo(
        'INTERNAL',
        'No pudimos abrir el pago de la seña. Probá de nuevo en un momento.',
      );
    }
    return SenaRequerida(intencion);
  }

  /// Estado de una seña. Es la ÚNICA fuente de verdad de la pantalla de pago:
  /// los parámetros que Mercado Pago agrega a la URL de vuelta viajan por el
  /// browser del cliente y son falsificables.
  Future<SenaEstado> estado(String depositId) async {
    final json = await _api.getJson(
      '/api/mobile/senas/${Uri.encodeComponent(depositId)}',
      timeout: AppConstants.senaTimeout,
    );
    return SenaEstado.fromJson(json);
  }
}

/// Copy humano de los códigos del contrato. Lo que no reconocemos se muestra
/// tal cual: el server ya manda texto en castellano en `message`.
String mensajeDeSena(String code, String? mensajeDelServer) {
  switch (code) {
    case 'MP_NO_CONECTADO':
      return 'Esta sucursal todavía no puede cobrar la seña online. '
          'Escribinos por WhatsApp y te reservamos el turno.';
    case 'MP_ERROR':
      return 'Mercado Pago no nos respondió. Probá de nuevo en un minuto.';
    case 'SLOT_TAKEN':
      return 'Ese horario ya fue tomado por alguien más. Elegí otro.';
    case 'TOO_LATE':
      return 'El horario seleccionado ya no está disponible. Elegí otro.';
    case 'ALREADY_BOOKED_TODAY':
      return 'Ya tenés un turno reservado para ese día. Si querés cambiarlo, '
          'cancelalo desde Mis turnos y reservá de nuevo.';
    case 'PRECIO_INVALIDO':
      return 'Ese servicio no tiene precio cargado, así que no podemos '
          'calcular la seña. Avisanos y lo resolvemos.';
    case 'NOT_BOOKABLE':
      return 'Esta sucursal no está tomando turnos online en este momento.';
    case 'UNAUTHENTICATED':
      return 'Tu sesión venció. Iniciá sesión de nuevo.';
    case 'TIMEOUT':
      return 'El pago tardó demasiado en abrirse. Probá de nuevo: si te '
          'llegó a aparecer un cobro, no lo repitas y escribinos.';
    case 'NETWORK':
      return 'Sin conexión. Revisá tu internet y probá de nuevo.';
    default:
      final m = mensajeDelServer?.trim();
      return (m == null || m.isEmpty)
          ? 'No pudimos abrir el pago de la seña. Probá de nuevo en un momento.'
          : m;
  }
}
