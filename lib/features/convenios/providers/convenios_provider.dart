import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

/// Lista de beneficios aprobados y vigentes para la org seleccionada.
/// Se filtra por RLS contra `clients.auth_user_id = auth.uid()`.
final conveniosProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.selectedOrgId == null) return [];

  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase
      .from('partner_benefits')
      .select(
        'id, title, description, discount_text, image_url, terms, '
        'location_address, location_map_url, valid_from, valid_until, '
        'organization_id, partner_id, '
        'partner:commercial_partners(id, business_name, logo_url)',
      )
      .eq('organization_id', auth.selectedOrgId!)
      .eq('status', 'approved')
      .order('approved_at', ascending: false);

  if (res is! List) return [];
  return res.map((e) => Map<String, dynamic>.from(e)).toList();
});

/// Detalle de un beneficio específico por id.
final conveniosDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, benefitId) async {
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase
      .from('partner_benefits')
      .select(
        'id, title, description, discount_text, image_url, terms, '
        'location_address, location_map_url, valid_from, valid_until, '
        'organization_id, partner_id, '
        'partner:commercial_partners(id, business_name, logo_url)',
      )
      .eq('id', benefitId)
      .eq('status', 'approved')
      .maybeSingle();

  if (res == null) return null;
  return Map<String, dynamic>.from(res);
});
