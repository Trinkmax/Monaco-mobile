import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

/// Resolves the client record ID from the auth user ID.
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

/// Global points balance for the authenticated client.
final globalPointsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase.rpc('get_client_global_points');
  // RPC returns TABLE → List with one row
  if (response is List && response.isNotEmpty) {
    return Map<String, dynamic>.from(response.first);
  }
  if (response is Map) {
    return Map<String, dynamic>.from(response);
  }
  return {
    'total_balance': 0,
    'total_earned': 0,
    'total_redeemed': 0,
  };
});

/// Transaction history for the authenticated client.
final pointsHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final clientId = await ref.watch(_clientIdProvider.future);
  if (clientId == null) return [];

  final response = await supabase
      .from('point_transactions')
      .select('*')
      .eq('client_id', clientId)
      .order('created_at', ascending: false)
      .limit(50);

  return List<Map<String, dynamic>>.from(response as List);
});

/// Points breakdown by branch for the authenticated client.
final branchPointsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final clientId = await ref.watch(_clientIdProvider.future);
  if (clientId == null) return [];

  final response = await supabase
      .from('client_points')
      .select('*, branches(name, address)')
      .eq('client_id', clientId);

  return List<Map<String, dynamic>>.from(response as List);
});
