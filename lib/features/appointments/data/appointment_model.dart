import 'package:monaco_mobile/features/senas/data/sena_models.dart';

import 'fechas.dart';

/// La seña del turno (fila de `booking_deposits`), cuando la hay.
///
/// Viaja embebida en la lectura de `appointments` (RLS
/// `booking_deposits_select_own_client`: el cliente ve las suyas). Existe por
/// una sola razón: **cancelar un turno señado sin decir una palabra sobre la
/// plata es lo que genera el reclamo**. Lo que la app sabe es que hay una seña
/// y cuánto; lo que NO sabe es si corresponde devolución —eso lo decide
/// `branch_deposit_settings.refund_on_early_cancel`, que el cliente no puede
/// leer— así que el copy nombra el monto y no promete el reintegro.
class AppointmentDeposit {
  final String id;
  final EstadoSena estado;
  final num amount;
  final num refundedAmount;
  final DateTime? paidAt;
  final DateTime? refundedAt;
  final DateTime? createdAt;

  const AppointmentDeposit({
    required this.id,
    required this.estado,
    required this.amount,
    this.refundedAmount = 0,
    this.paidAt,
    this.refundedAt,
    this.createdAt,
  });

  /// La plata salió del bolsillo del cliente y sigue del lado del local.
  /// `perdida` cuenta: la seña se la quedó el local, que es exactamente el caso
  /// en que hay algo que explicar.
  bool get plataDelLocal =>
      estado == EstadoSena.pagada ||
      estado == EstadoSena.consumida ||
      estado == EstadoSena.perdida;

  /// Ya se devolvió (total o parcialmente).
  bool get devuelta => estado == EstadoSena.devuelta || refundedAt != null;

  factory AppointmentDeposit.fromJson(Map<String, dynamic> j) =>
      AppointmentDeposit(
        id: (j['id'] as String?) ?? '',
        estado: EstadoSena.desde(j['status']),
        amount: (j['amount'] as num?) ?? num.tryParse('${j['amount']}') ?? 0,
        refundedAmount: (j['refunded_amount'] as num?) ?? 0,
        paidAt: DateTime.tryParse('${j['paid_at']}'),
        refundedAt: DateTime.tryParse('${j['refunded_at']}'),
        createdAt: DateTime.tryParse('${j['created_at']}'),
      );

  /// El embed llega como LISTA (`booking_deposits` apunta a `appointments`, o
  /// sea que es una relación a-muchos aunque en la práctica sea una sola).
  ///
  /// Un mismo turno puede tener más de una fila: el cliente que abandona un
  /// checkout y vuelve a intentar deja una `cancelada`/`expirada` atrás. Manda
  /// **la que tiene la plata**, y recién después la más nueva.
  static AppointmentDeposit? deLista(Object? raw) {
    if (raw is Map) return AppointmentDeposit.fromJson(Map<String, dynamic>.from(raw));
    if (raw is! List) return null;
    final filas = raw
        .whereType<Map>()
        .map((e) => AppointmentDeposit.fromJson(Map<String, dynamic>.from(e)))
        .where((d) => d.id.isNotEmpty)
        .toList();
    if (filas.isEmpty) return null;
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    filas.sort((a, b) => (b.createdAt ?? epoch).compareTo(a.createdAt ?? epoch));
    for (final d in filas) {
      if (d.plataDelLocal) return d;
    }
    for (final d in filas) {
      if (d.devuelta) return d;
    }
    return filas.first;
  }
}

/// Servicio asociado a un turno (snapshot al momento de agendar).
class AppointmentService {
  final String id;
  final String? name;
  final num? price;
  final int? durationMinutes;

  const AppointmentService({
    required this.id,
    this.name,
    this.price,
    this.durationMinutes,
  });

  /// Soporta dos formas:
  /// 1) fila de `appointment_services` con `price_snapshot`/`duration_snapshot`
  ///    y el join `services(name, price, duration_minutes)` embebido;
  /// 2) una fila plana de `services`.
  factory AppointmentService.fromJson(Map<String, dynamic> json) {
    final services = json['services'];
    if (services is Map) {
      final s = Map<String, dynamic>.from(services);
      return AppointmentService(
        id: (json['service_id'] as String?) ?? (s['id'] as String? ?? ''),
        name: s['name'] as String?,
        price: (json['price_snapshot'] as num?) ?? (s['price'] as num?),
        durationMinutes: (json['duration_snapshot'] as num?)?.toInt() ??
            (s['duration_minutes'] as num?)?.toInt(),
      );
    }
    return AppointmentService(
      id: (json['service_id'] as String?) ?? (json['id'] as String? ?? ''),
      name: json['name'] as String?,
      price: (json['price_snapshot'] as num?) ?? (json['price'] as num?),
      durationMinutes: (json['duration_snapshot'] as num?)?.toInt() ??
          (json['duration_minutes'] as num?)?.toInt(),
    );
  }
}

/// Estados que maneja la tabla `appointments`.
enum AppointmentStatus {
  scheduled,
  pendingPayment,
  confirmed,
  checkedIn,
  inProgress,
  completed,
  cancelled,
  noShow,
  unknown;

  static AppointmentStatus fromString(String? value) {
    switch (value) {
      case 'scheduled':
        return AppointmentStatus.scheduled;
      case 'pending_payment':
        return AppointmentStatus.pendingPayment;
      case 'confirmed':
        return AppointmentStatus.confirmed;
      case 'checked_in':
        return AppointmentStatus.checkedIn;
      case 'in_progress':
        return AppointmentStatus.inProgress;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'no_show':
        return AppointmentStatus.noShow;
      default:
        return AppointmentStatus.unknown;
    }
  }

  String get rawValue {
    switch (this) {
      case AppointmentStatus.scheduled:
        return 'scheduled';
      case AppointmentStatus.pendingPayment:
        return 'pending_payment';
      case AppointmentStatus.confirmed:
        return 'confirmed';
      case AppointmentStatus.checkedIn:
        return 'checked_in';
      case AppointmentStatus.inProgress:
        return 'in_progress';
      case AppointmentStatus.completed:
        return 'completed';
      case AppointmentStatus.cancelled:
        return 'cancelled';
      case AppointmentStatus.noShow:
        return 'no_show';
      case AppointmentStatus.unknown:
        return 'unknown';
    }
  }

  /// Etiqueta humana (misma tabla `ESTADOS` del turnero web).
  String get label {
    switch (this) {
      case AppointmentStatus.scheduled:
      case AppointmentStatus.confirmed:
        return 'Confirmado';
      case AppointmentStatus.pendingPayment:
        return 'Pendiente de pago';
      case AppointmentStatus.checkedIn:
        return 'Ya llegaste';
      case AppointmentStatus.inProgress:
        return 'En atención';
      case AppointmentStatus.completed:
        return 'Completado';
      case AppointmentStatus.cancelled:
        return 'Cancelado';
      case AppointmentStatus.noShow:
        return 'Ausente';
      case AppointmentStatus.unknown:
        return '—';
    }
  }

  /// Sigue vivo (aparece en "Próximos").
  bool get isActive =>
      this == AppointmentStatus.scheduled ||
      this == AppointmentStatus.pendingPayment ||
      this == AppointmentStatus.confirmed ||
      this == AppointmentStatus.checkedIn ||
      this == AppointmentStatus.inProgress;

  /// El cliente ya está en el local (no depende de la hora).
  bool get isAtShop =>
      this == AppointmentStatus.checkedIn || this == AppointmentStatus.inProgress;

  /// Estados desde los que se puede cancelar (mismo set que el server).
  bool get isCancellable =>
      this == AppointmentStatus.scheduled ||
      this == AppointmentStatus.confirmed ||
      this == AppointmentStatus.checkedIn;

  /// Estados que leemos en la pestaña "Próximos" (columna `status`).
  static const List<String> upcomingRaw = [
    'scheduled',
    'pending_payment',
    'confirmed',
    'checked_in',
    'in_progress',
  ];

  /// Estados que leemos en la pestaña "Anteriores".
  static const List<String> pastRaw = ['completed', 'cancelled', 'no_show'];
}

/// Turno del cliente, hidratado con sucursal, barbero y servicios.
///
/// `dateStr` + `startTime` son hora de PARED de la sucursal (`branchTimezone`).
/// Los instantes reales se calculan con `Fechas.instantOf`, nunca con la zona
/// del dispositivo.
class Appointment {
  final String id;
  final String organizationId;
  final String branchId;
  final String? branchName;
  final String? branchSlug;
  final String? branchAddress;
  final String? branchPhone;
  final String branchTimezone;
  final double? branchLatitude;
  final double? branchLongitude;
  final String clientId;
  final String? barberId;
  final String? barberName;
  final String? barberAvatarUrl;

  /// 'yyyy-MM-dd' (hora de pared de la sucursal).
  final String dateStr;

  /// 'HH:MM' (normalizado desde 'HH:MM:SS').
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final AppointmentStatus status;
  final String source;
  final String? cancellationToken;
  final DateTime? tokenExpiresAt;
  final String? notes;
  final List<AppointmentService> services;

  /// La seña, si este turno se reservó pagando una (`null` = no tiene).
  final AppointmentDeposit? deposit;

  const Appointment({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.clientId,
    required this.dateStr,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.status,
    required this.source,
    this.branchName,
    this.branchSlug,
    this.branchAddress,
    this.branchPhone,
    this.branchTimezone = Fechas.tzBuenosAires,
    this.branchLatitude,
    this.branchLongitude,
    this.barberId,
    this.barberName,
    this.barberAvatarUrl,
    this.cancellationToken,
    this.tokenExpiresAt,
    this.notes,
    this.services = const [],
    this.deposit,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    // Sucursal embebida (join: branches(...)).
    final branchRaw = json['branches'] ?? json['branch'];
    String? branchName;
    String? branchSlug;
    String? branchAddress;
    String? branchPhone;
    String? branchTz;
    double? branchLat;
    double? branchLng;
    if (branchRaw is Map) {
      final bm = Map<String, dynamic>.from(branchRaw);
      branchName = bm['name'] as String?;
      branchSlug = bm['slug'] as String?;
      branchAddress = bm['address'] as String?;
      branchPhone = bm['phone'] as String?;
      branchTz = bm['timezone'] as String?;
      branchLat = (bm['latitude'] as num?)?.toDouble();
      branchLng = (bm['longitude'] as num?)?.toDouble();
    }

    // Barbero embebido por COLUMNA (barber:barber_id(...)).
    final barberRaw = json['barber'] ?? json['staff'];
    String? barberName;
    String? barberAvatar;
    if (barberRaw is Map) {
      final sm = Map<String, dynamic>.from(barberRaw);
      barberName = (sm['full_name'] as String?) ?? (sm['name'] as String?);
      barberAvatar = sm['avatar_url'] as String?;
    }

    // Servicios: `appointment_services` sólo existe cuando el turno tiene más
    // de un servicio; si no, el principal viene en `service:service_id(...)`.
    final servicesRaw = json['appointment_services'] ?? json['services_list'];
    final services = <AppointmentService>[];
    if (servicesRaw is List) {
      final rows = servicesRaw.whereType<Map>().map((s) => Map<String, dynamic>.from(s)).toList()
        ..sort((a, b) => ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));
      for (final s in rows) {
        services.add(AppointmentService.fromJson(s));
      }
    }
    if (services.isEmpty) {
      final mainRaw = json['service'];
      if (mainRaw is Map) {
        services.add(AppointmentService.fromJson(Map<String, dynamic>.from(mainRaw)));
      } else if (json['service_id'] != null) {
        services.add(AppointmentService(id: json['service_id'] as String));
      }
    }

    final rawDate = (json['appointment_date'] as String?) ?? '';
    final dateStr = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;

    return Appointment(
      id: json['id'] as String,
      organizationId: (json['organization_id'] as String?) ?? '',
      branchId: (json['branch_id'] as String?) ?? '',
      clientId: (json['client_id'] as String?) ?? '',
      barberId: json['barber_id'] as String?,
      dateStr: dateStr,
      startTime: Fechas.hhmm((json['start_time'] as String?) ?? '00:00'),
      endTime: Fechas.hhmm((json['end_time'] as String?) ?? '00:00'),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      status: AppointmentStatus.fromString(json['status'] as String?),
      source: (json['source'] as String?) ?? 'public',
      cancellationToken: json['cancellation_token'] as String?,
      tokenExpiresAt: json['token_expires_at'] != null
          ? DateTime.tryParse(json['token_expires_at'] as String)
          : null,
      notes: json['notes'] as String?,
      services: services,
      deposit: AppointmentDeposit.deLista(json['deposit'] ?? json['booking_deposits']),
      branchName: branchName,
      branchSlug: branchSlug,
      branchAddress: branchAddress,
      branchPhone: branchPhone,
      branchTimezone: branchTz ?? Fechas.tzBuenosAires,
      branchLatitude: branchLat,
      branchLongitude: branchLng,
      barberName: barberName,
      barberAvatarUrl: barberAvatar,
    );
  }

  // ── Instantes (UTC) ────────────────────────────────────────────────────

  DateTime get startInstant => Fechas.instantOf(dateStr, startTime, branchTimezone);

  DateTime get endInstant {
    final end = Fechas.instantOf(dateStr, endTime, branchTimezone);
    // Un turno con end_time vacío o igual al inicio: usamos la duración.
    if (!end.isAfter(startInstant)) {
      return startInstant.add(Duration(minutes: durationMinutes > 0 ? durationMinutes : 30));
    }
    return end;
  }

  /// Día de la semana estilo JS (0 = domingo).
  int get dayOfWeek => Fechas.dayOfWeek(dateStr);

  /// Todavía "viene": está en el local, o no terminó.
  bool isLive({DateTime? now}) {
    if (!status.isActive) return false;
    if (status.isAtShop) return true;
    return endInstant.isAfter((now ?? DateTime.now()).toUtc());
  }

  /// Se puede cancelar desde la app: estado cancelable y faltan al menos
  /// `minHours` horas (la misma regla que aplica el server; acá sólo decide
  /// si mostrar el botón).
  bool canCancel({required int minHours, DateTime? now}) {
    if (!status.isCancellable) return false;
    final diff = startInstant.difference((now ?? DateTime.now()).toUtc());
    return diff.inMinutes >= minHours * 60;
  }

  // ── Formato ────────────────────────────────────────────────────────────

  /// "Miércoles, 6 de agosto".
  String get fechaLarga => Fechas.fechaLargaDeStr(dateStr);

  /// "Mié 6 ago".
  String get fechaCorta => Fechas.fechaCortaDeStr(dateStr);

  /// "Hoy" / "Mañana" / "Miércoles, 6 de agosto".
  String etiquetaDia({DateTime? now}) =>
      Fechas.etiquetaDia(dateStr, tz: branchTimezone, now: now);

  /// "15:00".
  String get horaLabel => startTime;

  /// Nombres separados por " + " (o "Servicio").
  String get servicesLabel {
    final names = services
        .map((s) => (s.name ?? '').trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.isEmpty) return 'Servicio';
    return names.join(' + ');
  }

  /// Total del snapshot de precios, si hay alguno.
  num? get totalPrice {
    num total = 0;
    var any = false;
    for (final s in services) {
      if (s.price != null) {
        total += s.price!;
        any = true;
      }
    }
    return any ? total : null;
  }

  bool get canOpenMaps =>
      (branchLatitude != null && branchLongitude != null) ||
      (branchAddress != null && branchAddress!.trim().isNotEmpty);

  String? get mapsUrl {
    if (branchLatitude != null && branchLongitude != null) {
      return 'https://www.google.com/maps/search/?api=1&query=$branchLatitude,$branchLongitude';
    }
    final addr = branchAddress?.trim();
    if (addr != null && addr.isNotEmpty) {
      return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}';
    }
    return null;
  }

  Appointment copyWith({AppointmentStatus? status}) => Appointment(
        id: id,
        organizationId: organizationId,
        branchId: branchId,
        clientId: clientId,
        dateStr: dateStr,
        startTime: startTime,
        endTime: endTime,
        durationMinutes: durationMinutes,
        status: status ?? this.status,
        source: source,
        branchName: branchName,
        branchSlug: branchSlug,
        branchAddress: branchAddress,
        branchPhone: branchPhone,
        branchTimezone: branchTimezone,
        branchLatitude: branchLatitude,
        branchLongitude: branchLongitude,
        barberId: barberId,
        barberName: barberName,
        barberAvatarUrl: barberAvatarUrl,
        cancellationToken: cancellationToken,
        tokenExpiresAt: tokenExpiresAt,
        notes: notes,
        services: services,
        deposit: deposit,
      );
}
