import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

class RedemptionData {
  final String redemptionId;
  final String code;
  final String status;
  final DateTime? usedAt;

  const RedemptionData({
    required this.redemptionId,
    required this.code,
    required this.status,
    this.usedAt,
  });

  bool get isUsed => status == 'used';
  bool get isIssued => status == 'issued';
  bool get isExpired => status == 'expired';
}

/// Emite (o recupera) el canje único del cliente para un beneficio dado.
/// La RPC `issue_benefit_redemption` resuelve el cliente vía auth.uid() y es
/// idempotente: el `ON CONFLICT` preserva el código original.
/// Este provider NO se ejecuta auto-mágicamente al abrir el detalle — solo
/// cuando el usuario toca "Activar mi código".
final redemptionProvider =
    FutureProvider.family<RedemptionData, String>((ref, benefitId) async {
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.rpc(
    'issue_benefit_redemption',
    params: {'p_benefit_id': benefitId},
  );

  if (res is List && res.isNotEmpty) {
    final first = Map<String, dynamic>.from(res.first as Map);
    return RedemptionData(
      redemptionId: first['redemption_id']?.toString() ?? '',
      code: first['code']?.toString() ?? '',
      status: first['status']?.toString() ?? 'issued',
      usedAt: first['used_at'] != null
          ? DateTime.tryParse(first['used_at'].toString())
          : null,
    );
  }
  throw StateError('No se pudo generar el código de canje');
});
