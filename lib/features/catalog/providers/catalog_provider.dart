import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

final catalogProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase
      .from('reward_catalog')
      .select()
      .eq('is_active', true)
      .gt('points_cost', 0)
      .order('points_cost');
  return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
});
