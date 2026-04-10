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
  });
}
