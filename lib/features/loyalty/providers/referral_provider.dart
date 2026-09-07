import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/features/loyalty/data/referido.dart';

/// Código personal de recomendación (`get_my_referral_code`, mig 197). El
/// server lo genera la primera vez que el cliente abre "Invitá a un amigo" y
/// después devuelve siempre el mismo; el QR lleva `MNC-REF:<código>`.
///
/// `null` = sin sesión o la RPC no devolvió texto: la pantalla lo trata como
/// error con reintentar, nunca dibuja un QR de la cadena vacía.
final referralCodeProvider = FutureProvider<String?>((ref) async {
  if (ref.watch(authProvider.select((a) => a.clientId)) == null) return null;
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.rpc('get_my_referral_code');
  if (res is String) {
    final code = res.trim();
    return code.isEmpty ? null : code;
  }
  debugPrint('[referral] get_my_referral_code devolvió ${res.runtimeType}');
  return null;
});

/// Mis invitaciones (`get_client_referrals`): como recomendador o como
/// invitado, más recientes primero.
final misReferidosProvider = FutureProvider<List<Referido>>((ref) async {
  if (ref.watch(authProvider.select((a) => a.clientId)) == null) return const [];
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.rpc('get_client_referrals');
  if (res is List) {
    return res
        .whereType<Map>()
        .map((e) => Referido.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  debugPrint('[referral] get_client_referrals devolvió ${res.runtimeType}');
  return const [];
});

/// Invalida el código y la lista (pull-to-refresh de `/invitar`).
void invalidarReferidos(WidgetRef ref) {
  ref.invalidate(referralCodeProvider);
  ref.invalidate(misReferidosProvider);
}
