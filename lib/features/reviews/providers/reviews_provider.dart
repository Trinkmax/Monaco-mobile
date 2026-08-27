import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

/// Atado al `clientId`: ver la nota en `rewards_provider.dart`.
final pendingReviewsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(authProvider.select((a) => a.clientId)) == null) return const [];
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.rpc('get_client_pending_reviews');
  if (res is List) {
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return [];
});
