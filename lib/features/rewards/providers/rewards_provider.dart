import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

/// Todo lo que sigue se ata al `clientId` de la sesión: son datos personales y
/// los providers son globales (sin `autoDispose`), así que al cerrar sesión
/// conservaban el `AsyncData` del cliente anterior. El siguiente que entraba
/// veía su saldo — y, en la tira de Premios, **su QR real y escaneable** —
/// hasta que hiciera pull-to-refresh. Con el `watch` del id, cambiar de cliente
/// (o quedarse sin sesión) recomputa el provider solo.

final clientWalletProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(authProvider.select((a) => a.clientId)) == null) return const [];
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.rpc('get_client_wallet');
  if (res is List) {
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return [];
});
