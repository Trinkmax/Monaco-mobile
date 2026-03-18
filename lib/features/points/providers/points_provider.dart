import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

/// Global points balance for the authenticated client.
final globalPointsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase.rpc('get_client_global_points');
  if (response is Map<String, dynamic>) {
    return response;
  }
  // Fallback structure
  return {
    'total_points': 0,
    'total_earned': 0,
    'total_redeemed': 0,
  };
});

/// Transaction history for the authenticated client.
final pointsHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final response = await supabase
      .from('point_transactions')
      .select('*')
      .eq('client_id', userId)
      .order('created_at', ascending: false)
      .limit(50);

  return List<Map<String, dynamic>>.from(response as List);
});

/// Points breakdown by branch for the authenticated client.
final branchPointsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final response = await supabase
      .from('client_points')
      .select('*, branches(name, address)')
      .eq('client_id', userId);

  return List<Map<String, dynamic>>.from(response as List);
});
