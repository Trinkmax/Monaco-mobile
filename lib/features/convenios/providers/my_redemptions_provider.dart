import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/redemption_provider.dart';

/// Historial completo de canjes del cliente autenticado.
/// Usa la RPC `list_my_redemptions` (SECURITY DEFINER) para incluir beneficios
/// que la RLS de `partner_benefits` normalmente ocultaría (archivados, vencidos,
/// rechazados, pausados).
final myRedemptionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.rpc('list_my_redemptions');
  if (res is! List) return [];
  return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

/// Mapa derivado: benefit_id → resumen del canje del cliente para ese beneficio.
/// Se usa en los cards (list + home carousel) para pintar el chip de estado.
/// Derivado de [myRedemptionsProvider] sin red extra.
final myBenefitRedemptionsMapProvider =
    Provider<AsyncValue<Map<String, Map<String, dynamic>>>>((ref) {
  return ref.watch(myRedemptionsProvider).whenData((list) {
    final map = <String, Map<String, dynamic>>{};
    for (final r in list) {
      final benefitId = r['benefit_id']?.toString();
      if (benefitId == null) continue;
      map[benefitId] = r;
    }
    return map;
  });
});

/// Lee el canje existente del cliente para un beneficio dado, SIN crearlo.
/// Usa SELECT directo sobre `partner_benefit_redemptions`; la RLS policy
/// "clients view own redemptions" permite esta lectura al cliente autenticado.
///
/// Devuelve `null` si el cliente todavía no activó el beneficio.
final existingRedemptionProvider =
    FutureProvider.family<RedemptionData?, String>((ref, benefitId) async {
  final supabase = ref.read(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  // Resolver client_id desde auth.uid()
  final clientRow = await supabase
      .from('clients')
      .select('id')
      .eq('auth_user_id', userId)
      .maybeSingle();
  final clientId = clientRow?['id']?.toString();
  if (clientId == null) return null;

  final row = await supabase
      .from('partner_benefit_redemptions')
      .select('id, code, status, used_at')
      .eq('benefit_id', benefitId)
      .eq('client_id', clientId)
      .maybeSingle();

  if (row == null) return null;
  return RedemptionData(
    redemptionId: row['id']?.toString() ?? '',
    code: row['code']?.toString() ?? '',
    status: row['status']?.toString() ?? 'issued',
    usedAt: row['used_at'] != null
        ? DateTime.tryParse(row['used_at'].toString())
        : null,
  );
});
