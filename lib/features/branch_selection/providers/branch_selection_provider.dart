import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:monaco_mobile/core/auth/secure_storage.dart';
import 'package:monaco_mobile/core/location/location_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/core/utils/constants.dart';

import '../models/branch_with_distance.dart';

/// Modo prueba (muestra la sucursal Test). Se prende desde Perfil con 7 toques
/// sobre la versión; quien lo cambie debe `ref.invalidate(testModeProvider)`
/// (o de `branchesProvider`) para que la lista lo refleje sin reabrir.
final testModeProvider = FutureProvider<bool>((ref) async {
  return SecureStorageService.isTestModeEnabled();
});

/// TODAS las sucursales activas de Monaco (incluida Test) con señales en vivo
/// y `operation_mode`/`slug` hidratados. Sin distancia: la ubicación se cruza
/// aparte para no bloquear la lista esperando al GPS.
///
/// `autoDispose`: cada vez que se abre la pantalla se vuelve a pedir el estado
/// en vivo, que es justamente lo que el cliente quiere ver fresco.
final allBranchesProvider = FutureProvider.autoDispose<List<BranchWithDistance>>(
  (ref) async {
    const orgId = AppConstants.organizationId;
    final client = ref.read(supabaseClientProvider);

    final response = await client.rpc(
      'get_org_branch_signals',
      params: {'p_org_id': orgId},
    );
    final rows = (response as List?) ?? const [];

    var branches = rows
        .map(
          (r) => BranchWithDistance.fromSignalRow(
            Map<String, dynamic>.from(r as Map),
          ),
        )
        .toList();

    // ── operation_mode + slug + is_active desde `branches` ─────────────────
    // El RPC no los expone. Si la query falla (RLS, red) dejamos los defaults:
    // la app sigue, sólo que sin el chip de turnos y sin slug.
    if (branches.isNotEmpty) {
      try {
        final ids = branches.map((b) => b.id).toList();
        final extras = await client
            .from('branches')
            .select('id, operation_mode, slug, is_active')
            .inFilter('id', ids);

        final byId = <String, Map<String, dynamic>>{};
        for (final row in (extras as List)) {
          final m = Map<String, dynamic>.from(row as Map);
          byId[m['id'] as String] = m;
        }

        branches = branches.where((b) => byId[b.id]?['is_active'] != false).map(
          (b) {
            final extra = byId[b.id];
            if (extra == null) return b;
            return b.copyWith(
              operationMode: (extra['operation_mode'] as String?) ?? 'walk_in',
              slug: extra['slug'] as String?,
            );
          },
        ).toList();
      } catch (e) {
        debugPrint('[branches] no se pudo hidratar operation_mode/slug: $e');
      }
    }

    branches.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return branches;
  },
);

/// Sucursales visibles: esconde Test salvo en modo prueba (§6.6 del contrato).
final branchesProvider = FutureProvider.autoDispose<List<BranchWithDistance>>((
  ref,
) async {
  final all = await ref.watch(allBranchesProvider.future);
  final testMode = await ref.watch(testModeProvider.future);
  if (testMode) return all;
  return all.where((b) => !b.isTest).toList();
});

/// Sucursales visibles + distancia al usuario, ordenadas por cercanía.
///
/// No espera a la ubicación: mientras el GPS resuelve, la lista sale sin
/// distancias y ordenada por nombre; cuando llega la posición, se reordena.
final branchesWithDistanceProvider =
    Provider.autoDispose<AsyncValue<List<BranchWithDistance>>>((ref) {
      final branches = ref.watch(branchesProvider);
      final location = ref.watch(userLocationProvider);
      final service = ref.read(locationServiceProvider);

      final Position? position = location.whenOrNull(data: (p) => p);

      List<BranchWithDistance> withDistances(List<BranchWithDistance> list) {
        final withDistance = list.map((b) {
          if (position == null || !b.hasCoordinates) {
            return b.copyWith(clearDistance: true);
          }
          return b.copyWith(
            distanceKm: service.distanceKm(
              position.latitude,
              position.longitude,
              b.latitude!,
              b.longitude!,
            ),
          );
        }).toList();

        withDistance.sort((a, b) {
          // Test siempre al final.
          if (a.isTest != b.isTest) return a.isTest ? 1 : -1;
          final da = a.distanceKm;
          final db = b.distanceKm;
          if (da != null && db != null) return da.compareTo(db);
          if (da != null) return -1;
          if (db != null) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return withDistance;
      }

      // `whenData` pierde el valor previo durante un refresh (devuelve un
      // AsyncLoading pelado) y la lista parpadearía a skeleton en cada
      // pull-to-refresh. Conservamos el dato anterior a mano.
      final previous = branches.valueOrNull;
      if (previous != null) {
        final data = AsyncData<List<BranchWithDistance>>(
          withDistances(previous),
        );
        if (branches.isLoading) {
          return const AsyncLoading<List<BranchWithDistance>>()
              .copyWithPrevious(data);
        }
        if (branches.hasError) {
          return AsyncError<List<BranchWithDistance>>(
            branches.error!,
            branches.stackTrace ?? StackTrace.current,
          ).copyWithPrevious(data);
        }
        return data;
      }
      return branches.whenData(withDistances);
    });

/// `true` mientras el GPS todavía no contestó (para el hint "Buscando tu
/// ubicación…" sin bloquear nada).
final locationPendingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(userLocationProvider).isLoading;
});
