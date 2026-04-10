import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:monaco_mobile/core/location/location_provider.dart';
import 'package:monaco_mobile/core/location/location_service.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import '../models/org_with_branches.dart';

/// Organizaciones cercanas, ordenadas por la sucursal más cercana al usuario.
final nearbyOrgsProvider =
    FutureProvider<List<OrgWithBranches>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final locationService = ref.read(locationServiceProvider);

  // Llamar al RPC que devuelve todas las orgs con sus branches
  final response = await client.rpc('get_nearby_organizations');
  final rows = response as List<dynamic>;

  // Ubicación es best-effort
  Position? position;
  try {
    position = await ref.watch(userLocationProvider.future);
  } catch (_) {}

  final orgs = rows.map((row) {
    final branchesJson = row['branches'] as List<dynamic>? ?? [];
    final branches = branchesJson.map((b) {
      return OrgBranch(
        id: b['id'] as String,
        name: b['name'] as String? ?? 'Sucursal',
        address: b['address'] as String?,
        latitude: (b['latitude'] as num?)?.toDouble(),
        longitude: (b['longitude'] as num?)?.toDouble(),
      );
    }).toList();

    // Calcular distancia mínima entre las branches de esta org y el usuario
    double? minDistance;
    if (position != null) {
      for (final b in branches) {
        if (b.latitude != null && b.longitude != null) {
          final d = locationService.distanceKm(
            position.latitude,
            position.longitude,
            b.latitude!,
            b.longitude!,
          );
          if (minDistance == null || d < minDistance) {
            minDistance = d;
          }
        }
      }
    }

    return OrgWithBranches(
      id: row['org_id'] as String,
      name: row['org_name'] as String? ?? 'Organización',
      slug: row['org_slug'] as String?,
      logoUrl: row['org_logo_url'] as String?,
      branchCount: (row['branch_count'] as num?)?.toInt() ?? branches.length,
      branches: branches,
      minDistanceKm: minDistance,
    );
  }).toList();

  // Ordenar: con distancia primero (por cercanía), sin distancia al final
  orgs.sort((a, b) {
    if (a.minDistanceKm != null && b.minDistanceKm != null) {
      return a.minDistanceKm!.compareTo(b.minDistanceKm!);
    }
    if (a.minDistanceKm != null) return -1;
    if (b.minDistanceKm != null) return 1;
    return a.name.compareTo(b.name);
  });

  return orgs;
});
