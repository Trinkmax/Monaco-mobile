import 'package:intl/intl.dart';

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

  factory AppointmentService.fromJson(Map<String, dynamic> json) {
    // Soporta dos formas:
    // 1) snapshot directo desde appointment_services con price_snapshot/duration_snapshot
    // 2) join `services(name, price, duration_minutes)` embebido como Map
    final services = json['services'];
    if (services is Map<String, dynamic>) {
      return AppointmentService(
        id: (json['service_id'] as String?) ?? (services['id'] as String? ?? ''),
        name: services['name'] as String?,
        price: (json['price_snapshot'] as num?) ?? (services['price'] as num?),
        durationMinutes: (json['duration_snapshot'] as num?)?.toInt() ??
            (services['duration_minutes'] as num?)?.toInt(),
      );
    }
    return AppointmentService(
      id: (json['service_id'] as String?) ?? (json['id'] as String? ?? ''),
      name: json['name'] as String?,
      price: json['price_snapshot'] as num? ?? json['price'] as num?,
      durationMinutes: (json['duration_snapshot'] as num?)?.toInt() ??
          (json['duration_minutes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (name != null) 'name': name,
        if (price != null) 'price': price,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
      };
}

/// Estados que maneja la tabla `appointments` en Supabase.
enum AppointmentStatus {
  scheduled,
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

  /// Etiqueta humana en español.
  String get label {
    switch (this) {
      case AppointmentStatus.scheduled:
      case AppointmentStatus.confirmed:
        return 'Confirmado';
      case AppointmentStatus.checkedIn:
        return 'Esperando';
      case AppointmentStatus.inProgress:
        return 'En atención';
      case AppointmentStatus.completed:
        return 'Realizado';
      case AppointmentStatus.cancelled:
        return 'Cancelado';
      case AppointmentStatus.noShow:
        return 'No asistió';
      case AppointmentStatus.unknown:
        return '—';
    }
  }
}

/// Turno agendado por el cliente. Hidrata los datos relacionales que se
/// suelen necesitar en la lista (sucursal, barbero, servicios) cuando vienen
/// como joins embebidos desde Supabase.
class Appointment {
  final String id;
  final String organizationId;
  final String branchId;
  final String? branchName;
  final String clientId;
  final String? barberId;
  final String? barberName;
  final DateTime appointmentDate; // local date
  final String startTime; // 'HH:mm:ss'
  final String endTime; // 'HH:mm:ss'
  final int durationMinutes;
  final AppointmentStatus status;
  final String source;
  final String? cancellationToken;
  final DateTime? tokenExpiresAt;
  final String? notes;
  final List<AppointmentService> services;

  // Branch extras útiles para navegar a Maps / armar links
  final double? branchLatitude;
  final double? branchLongitude;
  final String? branchAddress;

  const Appointment({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.clientId,
    required this.appointmentDate,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.status,
    required this.source,
    this.branchName,
    this.barberId,
    this.barberName,
    this.cancellationToken,
    this.tokenExpiresAt,
    this.notes,
    this.services = const [],
    this.branchLatitude,
    this.branchLongitude,
    this.branchAddress,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    // Branch embebido (join: branches(...))
    final branchRaw = json['branches'] ?? json['branch'];
    String? branchName;
    double? branchLat;
    double? branchLng;
    String? branchAddress;
    if (branchRaw is Map) {
      final bm = Map<String, dynamic>.from(branchRaw);
      branchName = bm['name'] as String?;
      branchLat = (bm['latitude'] as num?)?.toDouble();
      branchLng = (bm['longitude'] as num?)?.toDouble();
      branchAddress = bm['address'] as String?;
    }

    // Barber embebido (join: barber:staff(...))
    final barberRaw = json['barber'] ?? json['staff'];
    String? barberName;
    if (barberRaw is Map) {
      final sm = Map<String, dynamic>.from(barberRaw);
      barberName = (sm['full_name'] as String?) ?? (sm['name'] as String?);
    }

    // Services: lista de appointment_services con join services
    final servicesRaw = json['appointment_services'] ?? json['services_list'];
    final services = <AppointmentService>[];
    if (servicesRaw is List) {
      for (final s in servicesRaw) {
        if (s is Map) {
          services.add(AppointmentService.fromJson(
              Map<String, dynamic>.from(s)));
        }
      }
    } else if (json['service_id'] != null) {
      // Single service legacy
      services.add(AppointmentService(
        id: json['service_id'] as String,
        name: (json['services'] is Map)
            ? (json['services'] as Map)['name'] as String?
            : null,
      ));
    }

    final dateRaw = json['appointment_date'] as String?;
    final date = dateRaw != null
        ? DateTime.parse(dateRaw)
        : DateTime.now();

    return Appointment(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      branchId: json['branch_id'] as String,
      clientId: json['client_id'] as String,
      barberId: json['barber_id'] as String?,
      appointmentDate: date,
      startTime: (json['start_time'] as String?) ?? '00:00:00',
      endTime: (json['end_time'] as String?) ?? '00:00:00',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      status: AppointmentStatus.fromString(json['status'] as String?),
      source: (json['source'] as String?) ?? 'public',
      cancellationToken: json['cancellation_token'] as String?,
      tokenExpiresAt: json['token_expires_at'] != null
          ? DateTime.tryParse(json['token_expires_at'] as String)
          : null,
      notes: json['notes'] as String?,
      services: services,
      branchName: branchName,
      barberName: barberName,
      branchLatitude: branchLat,
      branchLongitude: branchLng,
      branchAddress: branchAddress,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organization_id': organizationId,
        'branch_id': branchId,
        'client_id': clientId,
        if (barberId != null) 'barber_id': barberId,
        'appointment_date':
            DateFormat('yyyy-MM-dd').format(appointmentDate),
        'start_time': startTime,
        'end_time': endTime,
        'duration_minutes': durationMinutes,
        'status': status.rawValue,
        'source': source,
        if (cancellationToken != null) 'cancellation_token': cancellationToken,
        if (notes != null) 'notes': notes,
      };

  /// Convierte fecha+hora local a un `DateTime` local para comparaciones.
  DateTime get startDateTime {
    final parts = startTime.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
      h,
      m,
    );
  }

  DateTime get endDateTime {
    final parts = endTime.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
      h,
      m,
    );
  }

  bool get isUpcoming {
    if (status == AppointmentStatus.cancelled ||
        status == AppointmentStatus.completed ||
        status == AppointmentStatus.noShow) {
      return false;
    }
    return startDateTime.isAfter(DateTime.now());
  }

  bool get isPast {
    return status == AppointmentStatus.completed ||
        status == AppointmentStatus.cancelled ||
        status == AppointmentStatus.noShow ||
        endDateTime.isBefore(DateTime.now());
  }

  /// Se puede cancelar si:
  ///  - status confirmed/scheduled/checked_in,
  ///  - falta más de 2h al start,
  ///  - hay token y todavía no expiró.
  bool get canCancel {
    if (status != AppointmentStatus.scheduled &&
        status != AppointmentStatus.confirmed &&
        status != AppointmentStatus.checkedIn) {
      return false;
    }
    if (cancellationToken == null) return false;
    if (tokenExpiresAt != null &&
        tokenExpiresAt!.isBefore(DateTime.now())) {
      return false;
    }
    final diff = startDateTime.difference(DateTime.now());
    return diff.inMinutes >= 120; // 2h mínimo
  }

  /// "Lunes 5 de mayo" — capitalizado.
  String get formattedDate {
    final s =
        DateFormat("EEEE d 'de' MMMM", 'es').format(appointmentDate.toLocal());
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }

  /// "14:30 hs"
  String get formattedTime {
    final parts = startTime.split(':');
    final h = parts.isNotEmpty ? parts[0].padLeft(2, '0') : '00';
    final m = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
    return '$h:$m hs';
  }

  /// Lista de servicios separada por " · ". Si no hay, fallback "Servicio".
  String get servicesLabel {
    final names = services
        .map((s) => s.name ?? '')
        .where((n) => n.trim().isNotEmpty)
        .toList();
    if (names.isEmpty) return 'Servicio';
    return names.join(' · ');
  }

  /// Total $ snapshot de los servicios (si están cargados los precios).
  num? get totalPrice {
    if (services.isEmpty) return null;
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
}
