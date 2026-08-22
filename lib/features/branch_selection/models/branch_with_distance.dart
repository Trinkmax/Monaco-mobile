import 'package:monaco_mobile/core/utils/constants.dart';

/// Sucursal con señales en vivo (`get_org_branch_signals`) + distancia
/// (best-effort) + `operation_mode`/`slug` hidratados desde `branches`.
class BranchWithDistance {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  /// `sin_espera | baja | media | alta` (lo calcula el RPC).
  final String occupancyLevel;
  final bool isOpen;
  final int etaMinutes;
  final int waitingCount;
  final int inProgressCount;
  final int availableBarbers;

  /// Barberos fichados ahora. Si es 0 la sucursal está efectivamente cerrada
  /// aunque `isOpen` diga que sí (fuera de turno).
  final int totalBarbers;

  /// Modo de operación de la sucursal: walk_in / appointments / hybrid.
  /// Default seguro = walk_in si no se hidrata desde la query a `branches`.
  final String operationMode;

  /// Slug público de la sucursal (`rondeau`, `parana`, …).
  final String? slug;

  const BranchWithDistance({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.occupancyLevel = 'baja',
    this.isOpen = true,
    this.etaMinutes = 0,
    this.waitingCount = 0,
    this.inProgressCount = 0,
    this.availableBarbers = 0,
    this.totalBarbers = 0,
    this.operationMode = 'walk_in',
    this.slug,
  });

  /// Esta sucursal acepta reservas online (modo `appointments` o `hybrid`).
  bool get acceptsAppointments =>
      operationMode == 'appointments' || operationMode == 'hybrid';

  /// Esta sucursal acepta walk-ins (modo `walk_in` o `hybrid`).
  bool get acceptsWalkIn =>
      operationMode == 'walk_in' || operationMode == 'hybrid';

  /// Sucursal de pruebas: la app la esconde salvo en modo prueba.
  bool get isTest => slug == AppConstants.testBranchSlug;

  /// Cerrada de verdad: el dueño la marcó cerrada o no hay nadie fichado.
  bool get isEffectivelyClosed => !isOpen || totalBarbers == 0;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Fila del RPC `get_org_branch_signals` (claves `branch_*`).
  factory BranchWithDistance.fromSignalRow(Map<String, dynamic> b) {
    return BranchWithDistance(
      id: b['branch_id'] as String,
      name: (b['branch_name'] as String?) ?? 'Sucursal',
      address: b['branch_address'] as String?,
      latitude: (b['branch_latitude'] as num?)?.toDouble(),
      longitude: (b['branch_longitude'] as num?)?.toDouble(),
      occupancyLevel: (b['occupancy_level'] ?? 'baja').toString(),
      isOpen: (b['is_open'] ?? true) == true,
      etaMinutes: (b['eta_minutes'] as num?)?.toInt() ?? 0,
      waitingCount: (b['waiting_count'] as num?)?.toInt() ?? 0,
      inProgressCount: (b['in_progress_count'] as num?)?.toInt() ?? 0,
      availableBarbers: (b['available_barbers'] as num?)?.toInt() ?? 0,
      totalBarbers: (b['total_barbers'] as num?)?.toInt() ?? 0,
    );
  }

  /// Forma genérica (claves planas), por compatibilidad.
  factory BranchWithDistance.fromJson(Map<String, dynamic> json) {
    return BranchWithDistance(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Sucursal',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      occupancyLevel: (json['occupancy_level'] ?? 'baja').toString(),
      isOpen: (json['is_open'] ?? true) == true,
      etaMinutes: (json['eta_minutes'] as num?)?.toInt() ?? 0,
      waitingCount: (json['waiting_count'] as num?)?.toInt() ?? 0,
      inProgressCount: (json['in_progress_count'] as num?)?.toInt() ?? 0,
      availableBarbers: (json['available_barbers'] as num?)?.toInt() ?? 0,
      totalBarbers: (json['total_barbers'] as num?)?.toInt() ?? 0,
      operationMode: (json['operation_mode'] as String?) ?? 'walk_in',
      slug: json['slug'] as String?,
    );
  }

  BranchWithDistance copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? distanceKm,
    bool clearDistance = false,
    String? occupancyLevel,
    bool? isOpen,
    int? etaMinutes,
    int? waitingCount,
    int? inProgressCount,
    int? availableBarbers,
    int? totalBarbers,
    String? operationMode,
    String? slug,
  }) {
    return BranchWithDistance(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: clearDistance ? null : (distanceKm ?? this.distanceKm),
      occupancyLevel: occupancyLevel ?? this.occupancyLevel,
      isOpen: isOpen ?? this.isOpen,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      waitingCount: waitingCount ?? this.waitingCount,
      inProgressCount: inProgressCount ?? this.inProgressCount,
      availableBarbers: availableBarbers ?? this.availableBarbers,
      totalBarbers: totalBarbers ?? this.totalBarbers,
      operationMode: operationMode ?? this.operationMode,
      slug: slug ?? this.slug,
    );
  }
}
