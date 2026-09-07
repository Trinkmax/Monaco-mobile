import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';

/// Estado del cliente en el programa de fidelización (`get_client_loyalty`).
///
/// Es dato personal y el provider es global (sin `autoDispose`), así que se
/// ata al `clientId` de la sesión como `clientWalletProvider`: al cerrar
/// sesión se recomputa solo y el siguiente cliente no ve la tarjeta del
/// anterior. Sin sesión devuelve [LoyaltySummary.disabled].
///
/// **Efecto lateral aceptado del server**: la primera llamada enrola al
/// cliente y le acredita el bono de bienvenida (si el programa está prendido).
///
/// El saldo de puntos del Home y de Premios sale de acá
/// (`saldoPuntosProvider` en `premios_provider.dart`), y los totales
/// Ganados/Canjeados de `/points` también (`points.earned_total` /
/// `redeemed_total`, que desde la mig 200 llegan con el programa apagado).
final loyaltyProvider = FutureProvider<LoyaltySummary>((ref) async {
  final clientId = ref.watch(authProvider.select((a) => a.clientId));
  if (clientId == null) return LoyaltySummary.disabled();
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.rpc('get_client_loyalty');
  if (res is Map) {
    final json = Map<String, dynamic>.from(res);
    if (json['error'] != null) {
      debugPrint('[loyalty] get_client_loyalty: ${json['error']}');
    }
    return LoyaltySummary.fromJson(json);
  }
  debugPrint('[loyalty] get_client_loyalty devolvió ${res.runtimeType}');
  return LoyaltySummary.disabled();
});

/// Invalida el estado del programa (saldo, categoría, vencimientos). Llamarlo
/// después de cualquier cosa que mueva puntos o visitas: canje, pull-to-refresh,
/// volver del local.
void invalidarLoyalty(WidgetRef ref) {
  ref.invalidate(loyaltyProvider);
}
