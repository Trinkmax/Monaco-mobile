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
