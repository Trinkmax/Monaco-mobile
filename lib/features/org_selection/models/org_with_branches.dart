/// Organización con sus sucursales y distancia mínima calculada.
class OrgWithBranches {
  final String id;
  final String name;
  final String? slug;
  final String? logoUrl;
  final int branchCount;
  final List<OrgBranch> branches;

  /// Distancia mínima entre las sucursales de esta org y el usuario.
  final double? minDistanceKm;

  const OrgWithBranches({
    required this.id,
    required this.name,
    this.slug,
    this.logoUrl,
    required this.branchCount,
    required this.branches,
    this.minDistanceKm,
  });
}

class OrgBranch {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;

  const OrgBranch({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
  });
}
