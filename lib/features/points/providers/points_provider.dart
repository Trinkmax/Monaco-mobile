import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

/// Los providers de este archivo son datos PERSONALES y globales (sin
/// `autoDispose`): se atan al `clientId` de la sesión para no seguir sirviendo
/// el saldo del cliente anterior después de un cierre de sesión. Ver la nota
/// larga en `rewards_provider.dart`.
///
/// Desde la migración 196 **los puntos son globales y viven en lotes**
/// (`point_transactions.remaining/expires_at`); `client_points` por sucursal ya
/// no se lee desde la app. El saldo, los vencimientos y los totales
/// Ganados/Canjeados salen todos de `loyaltyProvider` (`get_client_loyalty`,
/// que desde la mig 200 manda `earned_total`/`redeemed_total` también con el
/// programa apagado): `get_client_global_points` ya no se llama desde la app.

/// Historial de movimientos (`get_client_point_history`, mig 197): cada fila
/// es un LOTE (`points`, `remaining`, `expires_at`, `is_expired`) o un
/// movimiento negativo (`redeemed`, `expired`, `reversal`). La RPC resuelve el
/// cliente por `auth.uid()`; el `p_limit` lo acota el server a 300.
final pointsHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(authProvider.select((a) => a.clientId)) == null) return const [];
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase.rpc(
    'get_client_point_history',
    params: {'p_limit': 80},
  );
  if (response is List) {
    return response
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  debugPrint('[points] get_client_point_history devolvió ${response.runtimeType}');
  return const [];
});
