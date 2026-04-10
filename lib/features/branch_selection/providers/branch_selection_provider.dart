import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/location/location_provider.dart';
import 'package:monaco_mobile/core/location/location_service.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import '../models/branch_with_distance.dart';

/// Sucursales de la org seleccionada, con señales y distancia, ordenadas por cercanía.
final nearbyBranchesProvider =
    FutureProvider<List<BranchWithDistance>>((ref) async {
  final authState = ref.watch(authProvider);
  final orgId = authState.selectedOrgId;
  if (orgId == null) return [];

  final client = ref.read(supabaseClientProvider);
  final locationService = ref.read(locationServiceProvider);

  // Llamar al RPC que devuelve branches con señales para la org
  final response = await client.rpc(
    'get_org_branch_signals',
    params: {'p_org_id': orgId},
  );
  final rows = response as List<dynamic>;

  // Ubicación es best-effort
  Position? position;
  try {
    position = await ref.watch(userLocationProvider.future);
  } catch (_) {}

  final branches = rows.map((b) {
    final lat = (b['branch_latitude'] as num?)?.toDouble();
    final lng = (b['branch_longitude'] as num?)?.toDouble();

    double? distance;
    if (position != null && lat != null && lng != null) {
      distance = locationService.distanceKm(
        position.latitude,
        position.longitude,
        lat,
        lng,
      );
    }

    return BranchWithDistance(
      id: b['branch_id'] as String,
      name: b['branch_name'] as String? ?? 'Sucursal',
      address: b['branch_address'] as String?,
      latitude: lat,
      longitude: lng,
      distanceKm: distance,
      occupancyLevel: (b['occupancy_level'] ?? 'baja').toString(),
      isOpen: (b['is_open'] ?? true) as bool,
      etaMinutes: (b['eta_minutes'] ?? 0) as int,
      waitingCount: (b['waiting_count'] ?? 0) as int,
      availableBarbers: (b['available_barbers'] ?? 0) as int,
    );
  }).toList();

  // Ordenar: con distancia primero (por cercanía), sin distancia al final
  branches.sort((a, b) {
    if (a.distanceKm != null && b.distanceKm != null) {
      return a.distanceKm!.compareTo(b.distanceKm!);
    }
    if (a.distanceKm != null) return -1;
    if (b.distanceKm != null) return 1;
    return a.name.compareTo(b.name);
  });

  return branches;
});
