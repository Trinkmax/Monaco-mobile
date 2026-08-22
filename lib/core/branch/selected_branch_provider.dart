import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';

/// ID de la sucursal seleccionada por el cliente.
final selectedBranchIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).selectedBranchId;
});

/// Nombre de la sucursal seleccionada.
final selectedBranchNameProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).selectedBranchName;
});

/// Slug público de la sucursal seleccionada (`rondeau`, `parana`, …). Lo usa
/// el wizard de turnos para el bootstrap `/api/mobile/turnos/[slug]`.
final selectedBranchSlugProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).selectedBranchSlug;
});

/// La sucursal elegida como objeto, o `null` si todavía no eligió.
final selectedBranchProvider = Provider<SelectedBranch?>((ref) {
  final auth = ref.watch(authProvider);
  final id = auth.selectedBranchId;
  if (id == null) return null;
  return SelectedBranch(
    id: id,
    name: auth.selectedBranchName ?? 'Sucursal',
    slug: auth.selectedBranchSlug,
    operationMode: auth.selectedBranchOperationMode ?? 'walk_in',
  );
});

/// Vista inmutable de la sucursal elegida (lo que persiste `AuthState`).
class SelectedBranch {
  final String id;
  final String name;
  final String? slug;

  /// `walk_in | appointments | hybrid`.
  final String operationMode;

  const SelectedBranch({
    required this.id,
    required this.name,
    required this.slug,
    required this.operationMode,
  });

  bool get acceptsAppointments =>
      operationMode == 'appointments' || operationMode == 'hybrid';

  bool get acceptsWalkIn =>
      operationMode == 'walk_in' || operationMode == 'hybrid';

  @override
  bool operator ==(Object other) =>
      other is SelectedBranch &&
      other.id == id &&
      other.name == name &&
      other.slug == slug &&
      other.operationMode == operationMode;

  @override
  int get hashCode => Object.hash(id, name, slug, operationMode);
}
