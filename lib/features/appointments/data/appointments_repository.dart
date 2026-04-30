import 'package:supabase_flutter/supabase_flutter.dart';

import 'appointment_model.dart';

/// Repositorio que envuelve las queries a Supabase relacionadas con turnos.
///
/// Las RLS para clientes lee `appointments` filtrando por
/// `client_id IN (SELECT id FROM clients WHERE auth_user_id = auth.uid())`,
/// así que solo pasamos el `clientId` y el server ya valida.
class AppointmentsRepository {
  final SupabaseClient _client;

  AppointmentsRepository(this._client);

  /// Joins consistentes para hidratar branch + barber + servicios.
  /// `branches!inner` evita devolver filas con sucursal eliminada (FK rota).
  static const _selectFields = '''
    id,
    organization_id,
    branch_id,
    client_id,
    barber_id,
    appointment_date,
    start_time,
    end_time,
    duration_minutes,
    status,
    source,
    cancellation_token,
    token_expires_at,
    notes,
    branches!inner(id, name, address, latitude, longitude),
    barber:staff(id, full_name),
    appointment_services(
      id,
      service_id,
      sort_order,
      duration_snapshot,
      price_snapshot,
      services(id, name, price, duration_minutes)
    )
  ''';

  /// Turnos próximos del cliente: futuros (date >= hoy) y status activos.
  /// Ordena por fecha+hora ascendente.
  Future<List<Appointment>> fetchUpcoming(String clientId) async {
    final today =
        DateTime.now().toIso8601String().substring(0, 10); // yyyy-MM-dd
    final res = await _client
        .from('appointments')
        .select(_selectFields)
        .eq('client_id', clientId)
        .inFilter('status', ['scheduled', 'confirmed', 'checked_in', 'in_progress'])
        .gte('appointment_date', today)
        .order('appointment_date', ascending: true)
        .order('start_time', ascending: true);

    final list = (res as List)
        .map((row) => Appointment.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    // Filtrar fuera de fecha pero hoy con start anterior a now (no es upcoming)
    final now = DateTime.now();
    return list.where((a) {
      if (a.status == AppointmentStatus.inProgress) return true;
      return a.startDateTime
          .add(const Duration(minutes: 1))
          .isAfter(now);
    }).toList();
  }

  /// Turnos pasados del cliente: completed/cancelled/no_show, ordenados
  /// descendente (más recientes primero), limitados a 50.
  Future<List<Appointment>> fetchPast(String clientId) async {
    final res = await _client
        .from('appointments')
        .select(_selectFields)
        .eq('client_id', clientId)
        .inFilter('status', ['completed', 'cancelled', 'no_show'])
        .order('appointment_date', ascending: false)
        .order('start_time', ascending: false)
        .limit(50);

    return (res as List)
        .map((row) => Appointment.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Cancela el turno usando el `cancellation_token` (no requiere auth).
  /// El RPC actual valida ventana de 2h y devuelve `{ success, error? }`.
  /// El parámetro `reason` se acepta por simetría con la UI pero el RPC actual
  /// no lo persiste — lo guardamos como nota optimista en `notes` si hay.
  Future<void> cancelByToken(String token, {String? reason}) async {
    final res = await _client.rpc(
      'cancel_appointment_by_token',
      params: {'p_token': token},
    );

    final data = (res is Map) ? Map<String, dynamic>.from(res) : null;
    final ok = data != null && data['success'] == true;
    if (!ok) {
      final err = (data?['error'] as String?) ?? 'CANCEL_FAILED';
      throw AppointmentCancelException(err);
    }

    // Best-effort: persistir motivo en notes (no bloquea si falla por RLS).
    if (reason != null && reason.trim().isNotEmpty) {
      try {
        await _client
            .from('appointments')
            .update({
              'notes': 'Cancelación cliente: ${reason.trim()}',
            })
            .eq('cancellation_token', token);
      } catch (_) {
        // No-op: el cancel ya quedó registrado, esto es solo metadata.
      }
    }
  }
}

/// Errores conocidos del RPC `cancel_appointment_by_token`.
class AppointmentCancelException implements Exception {
  final String code;
  AppointmentCancelException(this.code);

  String get userMessage {
    switch (code) {
      case 'NOT_FOUND_OR_NOT_CANCELLABLE':
        return 'No pudimos encontrar el turno o ya no se puede cancelar.';
      case 'TOO_LATE':
        return 'Faltan menos de 2 horas para el turno. Comunicate con la barbería.';
      default:
        return 'No pudimos cancelar el turno. Intentalo de nuevo en un momento.';
    }
  }

  @override
  String toString() => 'AppointmentCancelException($code)';
}
