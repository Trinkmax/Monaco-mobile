import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

/// Resuelve el id del cliente a partir del auth user actual.
final _clientIdProvider = FutureProvider<String?>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final authId = supabase.auth.currentUser?.id;
  if (authId == null) return null;
  final res = await supabase
      .from('clients')
      .select('id')
      .eq('auth_user_id', authId)
      .maybeSingle();
  return res?['id'] as String?;
});

/// Lista de visitas del cliente autenticado, con joins a branches/staff/services.
/// Las RLS permiten a los clientes leer sus propias visitas
/// (visits_read_by_org — ver migration 048).
final visitsHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final clientId = await ref.watch(_clientIdProvider.future);
  if (clientId == null) return [];

  final response = await supabase
      .from('visits')
      .select(
        'id, amount, payment_method, notes, tags, '
        'started_at, completed_at, created_at, '
        'branches(name, address), '
        'staff:barber_id(full_name, avatar_url), '
        'services(name)',
      )
      .eq('client_id', clientId)
      .order('completed_at', ascending: false)
      .limit(100);

  return List<Map<String, dynamic>>.from(response as List);
});

/// Resumen agregado (cantidad y monto total gastado).
final visitsSummaryProvider = FutureProvider<Map<String, num>>((ref) async {
  final items = await ref.watch(visitsHistoryProvider.future);
  num total = 0;
  for (final v in items) {
    final amt = v['amount'];
    if (amt is num) total += amt;
    if (amt is String) total += num.tryParse(amt) ?? 0;
  }
  return {
    'count': items.length,
    'total_spent': total,
  };
});
