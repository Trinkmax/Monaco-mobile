import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/api/mobile_api.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

import '../data/appointment_model.dart';
import '../data/appointments_repository.dart';
import '../data/booking_api.dart';

/// Repositorio de lectura (PostgREST + RLS del cliente).
final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  return AppointmentsRepository(ref.watch(supabaseClientProvider));
});

/// Turnos próximos del cliente autenticado (estado activo, fecha >= hoy AR).
final upcomingAppointmentsProvider = FutureProvider<List<Appointment>>((ref) async {
  final clientId = ref.watch(authProvider.select((a) => a.clientId));
  if (clientId == null) return const [];
  return ref.read(appointmentsRepositoryProvider).fetchUpcoming(clientId);
});

/// Turnos pasados del cliente (últimos 50).
final pastAppointmentsProvider = FutureProvider<List<Appointment>>((ref) async {
  final clientId = ref.watch(authProvider.select((a) => a.clientId));
  if (clientId == null) return const [];
  return ref.read(appointmentsRepositoryProvider).fetchPast(clientId);
});

/// El próximo turno "vivo": el primero de los próximos que todavía no
/// terminó (o que ya está en el local). `null` si no hay.
final nextAppointmentProvider = Provider<AsyncValue<Appointment?>>((ref) {
  final upcoming = ref.watch(upcomingAppointmentsProvider);
  return upcoming.whenData((list) {
    final now = DateTime.now().toUtc();
    for (final a in list) {
      if (a.isLive(now: now)) return a;
    }
    return null;
  });
});

/// Un turno por id. Siempre lee fresco (es una query chica y el detalle
/// tiene que reflejar el estado real, no el de la lista cacheada).
final appointmentByIdProvider =
    FutureProvider.autoDispose.family<Appointment?, String>((ref, id) async {
  return ref.read(appointmentsRepositoryProvider).fetchById(id);
});

/// Invalida todo lo que muestra turnos (listas, próximo, detalle).
void invalidateAppointments(Ref ref, {String? appointmentId}) {
  ref.invalidate(upcomingAppointmentsProvider);
  ref.invalidate(pastAppointmentsProvider);
  if (appointmentId != null) ref.invalidate(appointmentByIdProvider(appointmentId));
}

/// Acciones sobre turnos existentes (por ahora: cancelar).
final appointmentActionsProvider = Provider<AppointmentActions>((ref) {
  return AppointmentActions(ref);
});

class AppointmentActions {
  final Ref _ref;
  const AppointmentActions(this._ref);

  /// Cancela por `POST /api/mobile/turnos/cancel` (camino TS completo: cola,
  /// mensajes, lista de espera). Devuelve `null` si salió bien o el mensaje
  /// de error para mostrar.
  Future<String?> cancel(String appointmentId) async {
    try {
      await _ref.read(bookingApiProvider).cancel(appointmentId);
      invalidateAppointments(_ref, appointmentId: appointmentId);
      return null;
    } on MobileApiException catch (e) {
      debugPrint('[turnos] cancelar $appointmentId falló: ${e.code} ${e.message}');
      // El estado pudo cambiar igual (ya cerrado): refrescamos.
      if (e.code == 'ALREADY_CLOSED' || e.code == 'NOT_FOUND') {
        invalidateAppointments(_ref, appointmentId: appointmentId);
      }
      return cancelErrorMessage(e);
    } catch (e) {
      debugPrint('[turnos] cancelar $appointmentId falló: $e');
      return 'No pudimos cancelar el turno. Probá de nuevo en un momento.';
    }
  }
}
