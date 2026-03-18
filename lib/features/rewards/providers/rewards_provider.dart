import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

final clientWalletProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.rpc('get_client_wallet');
  if (res is List) {
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return [];
});
