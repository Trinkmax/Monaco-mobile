import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/secure_storage.dart';

/// Modo prueba (deja de esconder la sucursal `test`). Se prende desde Perfil
/// con 7 toques sobre la versión; quien lo cambie debe
/// `ref.invalidate(testModeProvider)` para que las listas lo reflejen sin
/// reabrir la app.
///
/// Vivía en `features/branch_selection/providers/`, que se eliminó junto con la
/// sucursal global. Es lo único de esa feature que seguía en uso: lo consumen
/// `mobileBranchesProvider` y `_loadBranches` (turnos) y `branchSignalsProvider`
/// (sucursales en vivo).
final testModeProvider = FutureProvider<bool>((ref) async {
  return SecureStorageService.isTestModeEnabled();
});
