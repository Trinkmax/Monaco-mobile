import 'package:supabase_flutter/supabase_flutter.dart';

import 'appointment_model.dart';
import 'fechas.dart';

/// Lecturas de `appointments` por PostgREST con el JWT del cliente.
///
/// La RLS (`appointments_select_own_client`) ya filtra por
/// `client_id ∈ (SELECT id FROM clients WHERE auth_user_id = auth.uid())`;
/// pasamos `clientId` igual para que la query sea explícita y cacheable.
///
/// Las MUTACIONES (reservar, cancelar) NO van por acá: van por la API mobile
/// (`BookingApi`), que corre el camino TypeScript completo (mensajes de
/// WhatsApp, cola, lista de espera).
class AppointmentsRepository {
  final SupabaseClient _client;

  AppointmentsRepository(this._client);

  /// Joins para hidratar sucursal + barbero + servicios.
  ///
  /// - `branches!inner` evita devolver filas con sucursal borrada.
  /// - El barbero se embebe por COLUMNA (`barber:barber_id(...)`):
  ///   `appointments` tiene 4 FKs contra `staff` y `barber:staff(...)` hace
  ///   que PostgREST rechace la query ENTERA con PGRST201 (Known Risk #17).
  /// - `service:service_id(...)` trae el servicio principal: para un turno de
  ///   un solo servicio `appointment_services` viene vacío.
  /// - `deposit:booking_deposits!...` es la SEÑA del turno. Va con el nombre
  ///   del constraint aunque hoy haya una sola FK entre las dos tablas: es la
  ///   forma que no se rompe el día que alguien agregue la segunda (Known Risk
  ///   #15 — una FK nueva convierte todo embed por tabla en `PGRST201` y tira
  ///   la query ENTERA, no sólo ese campo). Verificado contra prod el
  ///   10/sep/2026: `booking_deposits_appointment_id_fkey` existe y la policy
  ///   `booking_deposits_select_own_client` deja al cliente leer las propias
  ///   (si no la dejara, el embed vendría vacío, no daría error).
  ///
  /// **Estas lecturas exigen sesión.** `anon` tiene SELECT sobre `appointments`
  /// pero NO sobre `booking_deposits`, así que con la anon key esta query
  /// entera muere con `42501 permission denied for table booking_deposits`
  /// (verificado contra prod). Hoy no pasa —un invitado no tiene `clientId` y
  /// el router no lo deja entrar a `/turnos/:id`—, pero si alguna vez hace
  /// falta leer un turno sin sesión, hay que armar OTRO select sin la seña, no
  /// reusar éste.
  static const selectFields = '''
    id,
    organization_id,
    branch_id,
    client_id,
    barber_id,
    service_id,
    appointment_date,
    start_time,
    end_time,
    duration_minutes,
    status,
    source,
    cancellation_token,
    token_expires_at,
    notes,
    branches!inner(id, name, slug, address, phone, timezone, latitude, longitude),
    barber:barber_id(id, full_name, avatar_url),
    service:service_id(id, name, price, duration_minutes),
    appointment_services(
      id,
      service_id,
      sort_order,
      duration_snapshot,
      price_snapshot,
      services(id, name, price, duration_minutes)
    ),
    deposit:booking_deposits!booking_deposits_appointment_id_fkey(
      id,
      status,
      amount,
      refunded_amount,
      paid_at,
      refunded_at,
      created_at
    )
  ''';

  /// Turnos próximos: estado activo y fecha >= HOY **de la sucursal**
  /// (UTC-3), no del dispositivo ni de `toIso8601String()`.
  ///
  /// No se filtra por hora: un turno confirmado de hoy cuya hora ya pasó
  /// sigue siendo "de hoy" hasta que el cron lo marque `no_show` o el
  /// barbero lo complete. Los que ya están en el local (`checked_in`,
  /// `in_progress`) se muestran siempre, por definición.
  Future<List<Appointment>> fetchUpcoming(String clientId) async {
    final today = Fechas.todayStr(Fechas.tzBuenosAires);
    final res = await _client
        .from('appointments')
        .select(selectFields)
        .eq('client_id', clientId)
        .inFilter('status', AppointmentStatus.upcomingRaw)
        .gte('appointment_date', today)
        .order('appointment_date', ascending: true)
        .order('start_time', ascending: true);

    final list = (res as List)
        .map((row) => Appointment.fromJson(Map<String, dynamic>.from(row)))
        .toList();

    // Los que ya están en el local van primero (es lo que está pasando AHORA).
    list.sort((a, b) {
      if (a.status.isAtShop != b.status.isAtShop) return a.status.isAtShop ? -1 : 1;
      return a.startInstant.compareTo(b.startInstant);
    });
    return list;
  }

  /// Turnos pasados: completed / cancelled / no_show, más recientes primero.
  Future<List<Appointment>> fetchPast(String clientId, {int limit = 50}) async {
    final res = await _client
        .from('appointments')
        .select(selectFields)
        .eq('client_id', clientId)
        .inFilter('status', AppointmentStatus.pastRaw)
        .order('appointment_date', ascending: false)
        .order('start_time', ascending: false)
        .limit(limit);

    return (res as List)
        .map((row) => Appointment.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Un turno por id (la RLS garantiza que sea propio). `null` si no existe.
  Future<Appointment?> fetchById(String id) async {
    final res = await _client
        .from('appointments')
        .select(selectFields)
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return Appointment.fromJson(Map<String, dynamic>.from(res));
  }
}
