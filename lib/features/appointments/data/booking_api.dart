import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/api/mobile_api.dart';

import 'booking_models.dart';

export 'booking_models.dart';

final bookingApiProvider = Provider<BookingApi>((ref) {
  return BookingApi(ref.watch(mobileApiProvider));
});

/// Cliente de los route handlers de turnos del dashboard
/// (`/api/mobile/turnos/*`). El motor de disponibilidad y de creación es UNO
/// solo y vive en el dashboard (`getAvailableSlots` / `createAppointment`):
/// acá no se reimplementa ninguna regla, sólo se mapea JSON a modelos.
///
/// Identidad: la API saca el cliente del JWT (Bearer que manda `MobileApi`);
/// nunca viaja teléfono ni `client_id` en el body.
class BookingApi {
  final MobileApi _api;
  const BookingApi(this._api);

  /// Sucursales activas de la org del cliente, con `bookable` ya resuelto
  /// por el server (modo + `appointment_settings.is_enabled`).
  Future<MobileBranchesResponse> fetchBranches() async {
    final json = await _api.getJson('/api/mobile/turnos/branches');
    return MobileBranchesResponse.fromJson(json);
  }

  /// Bootstrap del wizard de una sucursal. Lanza `MobileApiException` con
  /// `BRANCH_NOT_FOUND` (404) o `NOT_BOOKABLE` (409) además de los errores
  /// de red; el 200 también puede traer `bookable: false`.
  Future<BookingBootstrap> fetchBootstrap(String slug) async {
    final json = await _api.getJson('/api/mobile/turnos/${Uri.encodeComponent(slug)}');
    return BookingBootstrap.fromJson(json);
  }

  /// Disponibilidad de un día. Si el motor devuelve `error`, llega en
  /// `SlotsResponse.error` (200): la app lo muestra como "sin datos", nunca
  /// como "lleno".
  Future<SlotsResponse> fetchSlots({
    required String slug,
    required String date,
    required List<String> serviceIds,
    String? staffId,
  }) async {
    final json = await _api.getJson(
      '/api/mobile/turnos/${Uri.encodeComponent(slug)}/slots',
      query: {
        'date': date,
        'service_ids': serviceIds.join(','),
        if (staffId != null && staffId.isNotEmpty) 'staff_id': staffId,
      },
    );
    return SlotsResponse.fromJson(json);
  }

  /// Crea el turno. Los 409 del contrato (`SLOT_TAKEN`, `TOO_LATE`,
  /// `ALREADY_BOOKED_TODAY`, `PHONE_QUOTA_EXCEEDED`, `INVALID_PHONE`,
  /// `BOOKING_FAILED`) y el 429 `RATE_LIMITED` llegan como
  /// `MobileApiException(code, message)`.
  Future<BookingResult> book({
    required String slug,
    required String? staffId,
    required String date,
    required String startTime,
    required List<String> serviceIds,
    required int durationMinutes,
    String? name,
  }) async {
    final json = await _api.postJson(
      '/api/mobile/turnos/${Uri.encodeComponent(slug)}/book',
      {
        'staff_id': staffId,
        'date': date,
        'start_time': startTime,
        'service_ids': serviceIds,
        'duration_minutes': durationMinutes,
        if (name != null && name.trim().length >= 2) 'name': name.trim(),
      },
    );
    return BookingResult.fromJson(json);
  }

  /// Cancela un turno propio por id (el server verifica `client_id`). Errores:
  /// `NOT_FOUND` (404), `ALREADY_CLOSED` / `TOO_LATE_TO_CANCEL` (409),
  /// `CANCEL_FAILED` (500).
  Future<void> cancel(String appointmentId) async {
    await _api.postJson('/api/mobile/turnos/cancel', {'appointment_id': appointmentId});
  }
}

/// Copy humano para los errores de RESERVA (tabla §10 del turnero web). Lo
/// que no matchea un código conocido se muestra tal cual (el server ya manda
/// texto humano en `message`).
String bookingErrorMessage(MobileApiException e) {
  switch (e.code) {
    case 'INVALID_NAME':
      return 'El nombre debe tener al menos 2 caracteres.';
    case 'INVALID_PHONE':
      return 'Tu número de teléfono no es válido. Revisalo en tu perfil.';
    case 'PHONE_QUOTA_EXCEEDED':
      return 'Ya tenés varios turnos reservados. Si necesitás ayuda, comunicate con la sucursal.';
    case 'SLOT_TAKEN':
      return 'Ese horario ya fue tomado por alguien más. Elegí otro.';
    case 'TOO_LATE':
      return 'El horario seleccionado ya no está disponible. Elegí otro.';
    case 'ALREADY_BOOKED_TODAY':
      return 'Ya tenés un turno reservado para ese día. Si querés cambiarlo, cancelalo desde Mis turnos y reservá de nuevo.';
    case 'UNAUTHENTICATED':
      return 'Tu sesión venció. Iniciá sesión de nuevo.';
    case 'NO_CLIENT':
      return 'Tu cuenta no está vinculada a un cliente. Comunicate con la barbería.';
    case 'TIMEOUT':
    case 'NETWORK':
    case 'RATE_LIMITED':
    case 'BOOKING_FAILED':
    default:
      return e.message;
  }
}

/// Errores cuya causa es que la grilla quedó vieja: hay que recargarla.
bool bookingErrorNeedsReload(MobileApiException e) =>
    e.code == 'SLOT_TAKEN' || e.code == 'TOO_LATE';

/// Copy humano para los errores de CANCELACIÓN.
String cancelErrorMessage(MobileApiException e) {
  switch (e.code) {
    case 'NOT_FOUND':
      return 'No encontramos ese turno. Puede que ya haya sido cancelado.';
    case 'ALREADY_CLOSED':
      return 'El turno ya fue cancelado o completado.';
    case 'TOO_LATE_TO_CANCEL':
      // El server manda "No se puede cancelar con menos de N horas…".
      return '${e.message} Si no vas a poder venir, avisanos a la barbería.';
    case 'UNAUTHENTICATED':
      return 'Tu sesión venció. Iniciá sesión de nuevo.';
    default:
      return e.message.isNotEmpty
          ? e.message
          : 'No pudimos cancelar el turno. Probá de nuevo en un momento.';
  }
}
