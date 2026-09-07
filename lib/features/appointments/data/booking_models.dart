/// Modelos tipados de la API mobile de turnos (`/api/mobile/turnos/*`).
/// Espejan 1:1 los JSON del contrato (CONTRACTS.md §1.2). Todo `fromJson`
/// es tolerante a nulls y a números que llegan como `int`/`double`/`String`.
library;

import 'package:monaco_mobile/core/utils/constants.dart';

double? _toDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _toInt(Object? v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

String _str(Object? v, [String fallback = '']) => v?.toString() ?? fallback;

String? _strOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

List<int> _intList(Object? v) {
  if (v is! List) return const [];
  return v.map((e) => _toInt(e, -1)).where((e) => e >= 0).toList();
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

// ── Sucursales ─────────────────────────────────────────────────────────────

/// `GET /api/mobile/turnos/branches` → `branches[]`.
class MobileBranch {
  final String id;
  final String name;
  final String slug;
  final String? address;
  final String? phone;
  final String timezone;
  final double? latitude;
  final double? longitude;

  /// `walk_in | appointments | hybrid`.
  final String operationMode;

  /// `operation_mode != walk_in && settings.is_enabled` (lo decide el server).
  final bool bookable;
  final bool openNow;
  final String hoursLabel;

  /// Sucursal de pruebas (`slug == 'test'`): la app la esconde salvo en modo prueba.
  final bool isTest;

  const MobileBranch({
    required this.id,
    required this.name,
    required this.slug,
    this.address,
    this.phone,
    required this.timezone,
    this.latitude,
    this.longitude,
    required this.operationMode,
    required this.bookable,
    required this.openNow,
    required this.hoursLabel,
    required this.isTest,
  });

  bool get acceptsWalkIn => operationMode == 'walk_in' || operationMode == 'hybrid';
  bool get hasCoordinates => latitude != null && longitude != null;

  factory MobileBranch.fromJson(Map<String, dynamic> j) {
    final slug = _str(j['slug']);
    return MobileBranch(
      id: _str(j['id']),
      name: _str(j['name'], 'Sucursal'),
      slug: slug,
      address: _strOrNull(j['address']),
      phone: _strOrNull(j['phone']),
      timezone: _str(j['timezone'], 'America/Argentina/Buenos_Aires'),
      latitude: _toDouble(j['latitude']),
      longitude: _toDouble(j['longitude']),
      operationMode: _str(j['operation_mode'], 'walk_in'),
      bookable: j['bookable'] == true,
      openNow: j['open_now'] == true,
      hoursLabel: _str(j['hours_label']),
      isTest: j['is_test'] == true || slug == AppConstants.testBranchSlug,
    );
  }
}

class MobileBranchesResponse {
  final String serverToday;
  final List<MobileBranch> branches;

  const MobileBranchesResponse({required this.serverToday, required this.branches});

  factory MobileBranchesResponse.fromJson(Map<String, dynamic> j) {
    final list = j['branches'];
    return MobileBranchesResponse(
      serverToday: _str(j['server_today']),
      branches: list is List
          ? list.map((e) => MobileBranch.fromJson(_map(e))).toList()
          : const [],
    );
  }
}

// ── Bootstrap del wizard ───────────────────────────────────────────────────

class BookingBranch {
  final String id;
  final String name;
  final String slug;
  final String? address;
  final String? phone;
  final String timezone;
  final double? latitude;
  final double? longitude;
  final String operationMode;

  const BookingBranch({
    required this.id,
    required this.name,
    required this.slug,
    this.address,
    this.phone,
    required this.timezone,
    this.latitude,
    this.longitude,
    required this.operationMode,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  factory BookingBranch.fromJson(Map<String, dynamic> j) => BookingBranch(
        id: _str(j['id']),
        name: _str(j['name'], 'Sucursal'),
        slug: _str(j['slug']),
        address: _strOrNull(j['address']),
        phone: _strOrNull(j['phone']),
        timezone: _str(j['timezone'], 'America/Argentina/Buenos_Aires'),
        latitude: _toDouble(j['latitude']),
        longitude: _toDouble(j['longitude']),
        operationMode: _str(j['operation_mode'], 'walk_in'),
      );
}

class BookingSettings {
  final int maxAdvanceDays;

  /// Días habilitados YA recalculados por el server (0 = domingo).
  final List<int> appointmentDays;
  final int slotIntervalMinutes;
  final int cancellationMinHours;
  final int leadTimeMinutes;
  final int bufferMinutes;

  const BookingSettings({
    required this.maxAdvanceDays,
    required this.appointmentDays,
    required this.slotIntervalMinutes,
    required this.cancellationMinHours,
    required this.leadTimeMinutes,
    required this.bufferMinutes,
  });

  factory BookingSettings.fromJson(Map<String, dynamic> j) => BookingSettings(
        maxAdvanceDays: _toInt(j['max_advance_days'], 15),
        appointmentDays: _intList(j['appointment_days']),
        slotIntervalMinutes: _toInt(j['slot_interval_minutes'], 15),
        cancellationMinHours: _toInt(j['cancellation_min_hours'], 2),
        leadTimeMinutes: _toInt(j['lead_time_minutes'], 0),
        bufferMinutes: _toInt(j['buffer_minutes'], 0),
      );
}

/// `deposit` del bootstrap: lo que hace falta para **anunciar** la seña antes
/// de que el cliente elija nada.
///
/// No alcanza para calcularla, y no tiene que alcanzar: el monto exacto —con su
/// moneda— lo escribe el server (`PoliticaSena.titulo`, "Seña $8.000 ARS").
/// Reimplementar `calcularSena` acá es cómo se llega a que la pantalla diga un
/// número y Mercado Pago cobre otro.
class AvisoSena {
  /// La sucursal cobra seña **por la app** (`is_enabled` + canal habilitado).
  final bool enabled;

  /// Porcentaje del total que se cobra por adelantado.
  final int percentage;

  /// Debajo de este monto la seña no se cobra (no vale la fricción ni la
  /// comisión de Mercado Pago).
  final num minAmount;

  const AvisoSena({
    this.enabled = false,
    this.percentage = 50,
    this.minAmount = 0,
  });

  /// ¿Se anuncia la seña para un carrito de `total`?
  ///
  /// Sin servicio elegido (`total <= 0`) se anuncia igual: el aviso existe
  /// justamente para que el cliente se entere ANTES de elegir. Con servicios
  /// elegidos, sólo si la parte a señar llega al mínimo de la sucursal.
  ///
  /// La comparación es **conservadora**: el server redondea la seña hacia
  /// arriba, así que puede haber un caso donde él la cobre y acá no se anuncie.
  /// Anunciar de menos es un cartel que falta; anunciar de más es prometer un
  /// cobro que no va a existir.
  bool anunciaPara(num total) {
    if (!enabled) return false;
    if (total <= 0) return true;
    return total * percentage / 100 >= minAmount;
  }

  factory AvisoSena.fromJson(Map<String, dynamic> j) {
    final pct = _toInt(j['percentage'], 50);
    return AvisoSena(
      enabled: j['enabled'] == true,
      percentage: pct < 1 ? 1 : (pct > 100 ? 100 : pct),
      minAmount: _toDouble(j['min_amount']) ?? 0,
    );
  }
}

class BookingBranding {
  final String? logoUrl;
  final String? welcomeMessage;
  const BookingBranding({this.logoUrl, this.welcomeMessage});

  factory BookingBranding.fromJson(Map<String, dynamic> j) => BookingBranding(
        logoUrl: _strOrNull(j['logo_url']),
        welcomeMessage: _strOrNull(j['welcome_message']),
      );
}

class PublicService {
  final String id;
  final String name;
  final num price;

  /// `null` = el motor cuenta `slot_interval_minutes`.
  final int? durationMinutes;
  final String bookingMode;
  final String? availability;

  const PublicService({
    required this.id,
    required this.name,
    required this.price,
    this.durationMinutes,
    required this.bookingMode,
    this.availability,
  });

  factory PublicService.fromJson(Map<String, dynamic> j) => PublicService(
        id: _str(j['id']),
        name: _str(j['name'], 'Servicio'),
        price: (j['price'] is num)
            ? j['price'] as num
            : (num.tryParse(_str(j['price'], '0')) ?? 0),
        durationMinutes:
            j['duration_minutes'] == null ? null : _toInt(j['duration_minutes']),
        bookingMode: _str(j['booking_mode'], 'self_service'),
        availability: _strOrNull(j['availability']),
      );
}

/// Franja horaria 'HH:MM'–'HH:MM'.
typedef TimeRange = ({String start, String end});

/// Barbero reservable: días que toma turnos y, por día, las franjas REALES
/// (cruce de su ventana con la de la sucursal).
class PublicStaff {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final List<int> days;
  final Map<int, List<TimeRange>> windows;

  const PublicStaff({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.days,
    required this.windows,
  });

  List<TimeRange> windowsFor(int dayOfWeek) => windows[dayOfWeek] ?? const [];

  factory PublicStaff.fromJson(Map<String, dynamic> j) {
    final windows = <int, List<TimeRange>>{};
    final rawWindows = j['windows'];
    if (rawWindows is Map) {
      rawWindows.forEach((k, v) {
        final day = int.tryParse(k.toString());
        if (day == null || v is! List) return;
        final rangos = <TimeRange>[];
        for (final r in v) {
          final m = _map(r);
          final start = _strOrNull(m['start']);
          final end = _strOrNull(m['end']);
          if (start != null && end != null) rangos.add((start: start, end: end));
        }
        if (rangos.isNotEmpty) windows[day] = rangos;
      });
    }
    return PublicStaff(
      id: _str(j['id']),
      fullName: _str(j['full_name'], 'Barbero'),
      avatarUrl: _strOrNull(j['avatar_url']),
      days: _intList(j['days']),
      windows: windows,
    );
  }
}

/// Barbero que atiende sólo por orden de llegada.
class WalkInStaff {
  final String id;
  final String fullName;
  final String? avatarUrl;

  const WalkInStaff({required this.id, required this.fullName, this.avatarUrl});

  factory WalkInStaff.fromJson(Map<String, dynamic> j) => WalkInStaff(
        id: _str(j['id']),
        fullName: _str(j['full_name'], 'Barbero'),
        avatarUrl: _strOrNull(j['avatar_url']),
      );
}

class ClientUpcoming {
  final String date; // 'yyyy-MM-dd'
  final String time; // 'HH:MM'
  const ClientUpcoming({required this.date, required this.time});

  factory ClientUpcoming.fromJson(Map<String, dynamic> j) => ClientUpcoming(
        date: _str(j['date']),
        time: _str(j['time']),
      );
}

class BookingClient {
  final String firstName;
  final String lastName;
  final String phone;
  final ClientUpcoming? upcoming;

  const BookingClient({
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.upcoming,
  });

  String get fullName =>
      [firstName, lastName].map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ');

  factory BookingClient.fromJson(Map<String, dynamic> j) => BookingClient(
        firstName: _str(j['first_name']).trim(),
        lastName: _str(j['last_name']).trim(),
        phone: _str(j['phone']),
        upcoming: j['upcoming'] is Map ? ClientUpcoming.fromJson(_map(j['upcoming'])) : null,
      );
}

/// `GET /api/mobile/turnos/[slug]`.
class BookingBootstrap {
  final String serverToday;
  final DateTime serverNow;
  final BookingBranch branch;
  final bool bookable;
  final BookingSettings settings;
  final BookingBranding branding;
  final List<PublicService> services;
  final List<PublicStaff> staff;
  final List<WalkInStaff> walkInStaff;
  final BookingClient client;

  /// Si esta sucursal cobra seña por la app, para anunciarlo desde el paso 1.
  final AvisoSena deposit;

  /// Instante local en que se recibió: "ahora" = `serverNow + (now - fetchedAt)`.
  final DateTime fetchedAt;

  const BookingBootstrap({
    required this.serverToday,
    required this.serverNow,
    required this.branch,
    required this.bookable,
    required this.settings,
    required this.branding,
    required this.services,
    required this.staff,
    required this.walkInStaff,
    required this.client,
    this.deposit = const AvisoSena(),
    required this.fetchedAt,
  });

  /// "Ahora" según el reloj del servidor, corrido por el tiempo transcurrido
  /// desde el bootstrap. Evita depender del reloj del teléfono para la
  /// ventana de reserva.
  DateTime get nowFromServer =>
      serverNow.add(DateTime.now().difference(fetchedAt));

  factory BookingBootstrap.fromJson(Map<String, dynamic> j) {
    final services = j['services'];
    final staff = j['staff'];
    final walkIn = j['walk_in_staff'];
    final now = DateTime.now();
    return BookingBootstrap(
      serverToday: _str(j['server_today']),
      serverNow: DateTime.tryParse(_str(j['server_now']))?.toUtc() ?? now.toUtc(),
      branch: BookingBranch.fromJson(_map(j['branch'])),
      bookable: j['bookable'] == true,
      settings: BookingSettings.fromJson(_map(j['settings'])),
      branding: BookingBranding.fromJson(_map(j['branding'])),
      services: services is List
          ? services.map((e) => PublicService.fromJson(_map(e))).toList()
          : const [],
      staff: staff is List
          ? staff.map((e) => PublicStaff.fromJson(_map(e))).toList()
          : const [],
      walkInStaff: walkIn is List
          ? walkIn.map((e) => WalkInStaff.fromJson(_map(e))).toList()
          : const [],
      client: BookingClient.fromJson(_map(j['client'])),
      // Un bootstrap viejo (server sin `deposit`) queda en "no cobra seña": no
      // se anuncia nada y el flujo sigue igual. El que decide de verdad es
      // `POST /sena`, no este aviso.
      deposit: AvisoSena.fromJson(_map(j['deposit'])),
      fetchedAt: now,
    );
  }
}

// ── Disponibilidad ─────────────────────────────────────────────────────────

class SlotItem {
  final String time; // 'HH:MM'
  final bool available;
  const SlotItem({required this.time, required this.available});

  factory SlotItem.fromJson(Map<String, dynamic> j) => SlotItem(
        time: _str(j['time']),
        available: j['available'] == true,
      );
}

/// Un grupo por barbero con TODOS sus slots (disponibles y no).
class SlotGroup {
  final String staffId;
  final String staffName;
  final String? staffAvatarUrl;
  final List<SlotItem> slots;

  const SlotGroup({
    required this.staffId,
    required this.staffName,
    this.staffAvatarUrl,
    required this.slots,
  });

  bool get hasCupo => slots.any((s) => s.available);
  Iterable<SlotItem> get available => slots.where((s) => s.available);

  factory SlotGroup.fromJson(Map<String, dynamic> j) {
    final slots = j['slots'];
    return SlotGroup(
      staffId: _str(j['staff_id']),
      staffName: _str(j['staff_name'], 'Barbero'),
      staffAvatarUrl: _strOrNull(j['staff_avatar_url']),
      slots: slots is List
          ? slots.map((e) => SlotItem.fromJson(_map(e))).toList()
          : const [],
    );
  }
}

/// `GET /api/mobile/turnos/[slug]/slots`. Si `error` viene, la lista NO es
/// confiable ("sin datos", nunca "lleno").
class SlotsResponse {
  final String serverToday;
  final List<SlotGroup> groups;
  final String? error;

  const SlotsResponse({required this.serverToday, required this.groups, this.error});

  bool get ok => error == null;

  factory SlotsResponse.fromJson(Map<String, dynamic> j) {
    final slots = j['slots'];
    return SlotsResponse(
      serverToday: _str(j['server_today']),
      groups: slots is List
          ? slots.map((e) => SlotGroup.fromJson(_map(e))).toList()
          : const [],
      error: _strOrNull(j['error']),
    );
  }
}

// ── Reserva ────────────────────────────────────────────────────────────────

/// `POST /api/mobile/turnos/[slug]/book` → 200.
class BookingResult {
  final String appointmentId;
  final Map<String, dynamic> appointment;
  final String? cancellationToken;
  final bool clientIsNew;
  final bool clientHasFace;

  const BookingResult({
    required this.appointmentId,
    required this.appointment,
    this.cancellationToken,
    required this.clientIsNew,
    required this.clientHasFace,
  });

  /// `confirmed` / `pending_payment` (prepago). No asumir `confirmed`.
  String get status => _str(appointment['status'], 'confirmed');

  factory BookingResult.fromJson(Map<String, dynamic> j) {
    final appt = _map(j['appointment']);
    return BookingResult(
      appointmentId: _str(appt['id']),
      appointment: appt,
      cancellationToken: _strOrNull(j['cancellation_token']),
      clientIsNew: j['client_is_new'] == true,
      clientHasFace: j['client_has_face'] == true,
    );
  }
}
