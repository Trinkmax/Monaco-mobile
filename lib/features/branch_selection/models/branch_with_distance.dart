class BranchWithDistance {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final String occupancyLevel;
  final bool isOpen;
  final int etaMinutes;
  final int waitingCount;
  final int availableBarbers;

  /// Modo de operación de la sucursal: walk_in / appointments / hybrid.
  /// Default seguro = walk_in si no se hidrata desde la query a `branches`.
  final String operationMode;

  /// Slug público de la sucursal (usado para el link de reserva web).
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
    this.availableBarbers = 0,
    this.operationMode = 'walk_in',
    this.slug,
  });

  /// Esta sucursal acepta reservas online (modo `appointments` o `hybrid`).
  bool get acceptsAppointments =>
      operationMode == 'appointments' || operationMode == 'hybrid';

  /// Esta sucursal acepta walk-ins (modo `walk_in` o `hybrid`).
  bool get acceptsWalkIn =>
      operationMode == 'walk_in' || operationMode == 'hybrid';

  factory BranchWithDistance.fromJson(Map<String, dynamic> json) {
    return BranchWithDistance(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Sucursal',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      occupancyLevel: (json['occupancy_level'] ?? 'baja').toString(),
      isOpen: (json['is_open'] ?? true) as bool,
      etaMinutes: (json['eta_minutes'] as num?)?.toInt() ?? 0,
      waitingCount: (json['waiting_count'] as num?)?.toInt() ?? 0,
      availableBarbers: (json['available_barbers'] as num?)?.toInt() ?? 0,
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
    String? occupancyLevel,
    bool? isOpen,
    int? etaMinutes,
    int? waitingCount,
    int? availableBarbers,
    String? operationMode,
    String? slug,
  }) {
    return BranchWithDistance(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: distanceKm ?? this.distanceKm,
      occupancyLevel: occupancyLevel ?? this.occupancyLevel,
      isOpen: isOpen ?? this.isOpen,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      waitingCount: waitingCount ?? this.waitingCount,
      availableBarbers: availableBarbers ?? this.availableBarbers,
      operationMode: operationMode ?? this.operationMode,
      slug: slug ?? this.slug,
    );
  }
}
