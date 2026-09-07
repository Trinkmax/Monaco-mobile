import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/core/utils/formatters.dart';

final _pts = NumberFormat.decimalPattern('es_AR');

/// Fila de un movimiento de puntos (`get_client_point_history`, mig 197).
/// Está pensada para vivir dentro de un `LiquidSectionCard` (no dibuja su
/// propia lámina): ícono por tipo en mini-vidrio, descripción, tiempo relativo
/// y el delta con signo.
///
/// Un movimiento positivo es un LOTE con vencimiento propio: si sigue vivo, la
/// segunda línea dice "Vence en 40 días" y, si ya se consumió en parte,
/// "· quedan 80". Un lote vencido (`is_expired`) se atenúa y se pinta gris,
/// igual que el movimiento `expired` que lo dio de baja: no es plata que se
/// perdió hoy, es historia. Un lote **revertido** (visita anulada, referido
/// anulado: `loyalty_reverse_lot` lo deja en `remaining = 0` y escribe
/// `meta.reversed_at`) se atenúa igual y dice "Revertido": la RPC no expone
/// `reversed_by`, y sin mirar el `meta` se leía "Ya usado" al lado de la fila
/// "Reversión: visita anulada", como si el cliente hubiera gastado puntos que
/// en realidad le quitaron.
class PointsHistoryTile extends StatelessWidget {
  final Map<String, dynamic> transaction;

  /// Reloj inyectable para los tests de "vence en N días".
  final DateTime? ahora;

  const PointsHistoryTile({super.key, required this.transaction, this.ahora});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final points = (t['points'] as num?)?.toInt() ?? 0;
    final isEarned = points >= 0;
    final type = (t['type'] ?? '').toString();
    final description = _describe(t['description'] as String?, type);
    final createdAt = _fecha(t['created_at']);
    final expiresAt = _fecha(t['expires_at']);
    final remaining = (t['remaining'] as num?)?.toInt();
    final isExpired = t['is_expired'] == true;
    final isReversed = _revertido(t);
    final apagado = isExpired || isReversed || type == 'expired';

    final accent = apagado
        ? Colors.white.withValues(alpha: 0.45)
        : isEarned
            ? MonacoColors.monacoGreen
            : MonacoColors.destructive;
    final icon = _iconFor(type, isEarned);
    final vencimiento = _lineaVencimiento(
      points: points,
      remaining: remaining,
      expiresAt: expiresAt,
      isExpired: isExpired,
      isReversed: isReversed,
      ahora: ahora ?? DateTime.now(),
    );

    return Opacity(
      opacity: apagado ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.24),
                    accent.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(color: accent.withValues(alpha: 0.32), width: 0.8),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MonacoColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (createdAt != null || vencimiento != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (createdAt != null) Formatters.relativeTime(createdAt),
                        ?vencimiento,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${isEarned ? '+' : ''}${_pts.format(points)}',
              style: TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 3),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'pts',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Vence en 40 días" / "Vence hoy" / "Vencido", más "quedan 80" si el lote
  /// se consumió en parte. Sólo para lotes positivos; los movimientos negativos
  /// no vencen.
  static String? _lineaVencimiento({
    required int points,
    required int? remaining,
    required DateTime? expiresAt,
    required bool isExpired,
    required bool isReversed,
    required DateTime ahora,
  }) {
    if (points <= 0) return null;
    if (isReversed) return 'Revertido';
    if (isExpired) return 'Vencido';
    if (expiresAt == null) return null;
    final diff = expiresAt.difference(ahora);
    if (diff.isNegative) {
      // El lote venció pero el server todavía no lo marcó (el cron corre una
      // vez por día): se lo dice igual, sin inventar que quedan puntos.
      return 'Vencido';
    }
    final dias = (diff.inMinutes / (60 * 24)).ceil();
    final vence = dias <= 0
        ? 'Vence hoy'
        : dias == 1
            ? 'Vence mañana'
            : 'Vence en $dias días';
    if (remaining != null && remaining < points && remaining > 0) {
      return '$vence · quedan ${_pts.format(remaining)}';
    }
    if (remaining == 0) return 'Ya usado';
    return vence;
  }

  static DateTime? _fecha(Object? v) {
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }

  /// Lote revertido: `reversed_by` si algún día la RPC lo expone; mientras
  /// tanto, las marcas que `loyalty_reverse_lot` (mig 199) deja en `meta`.
  static bool _revertido(Map<String, dynamic> t) {
    if (t['reversed_by'] != null) return true;
    final meta = t['meta'];
    if (meta is! Map) return false;
    return meta['reversed_at'] != null || meta['reversal_reason'] != null;
  }

  static String _describe(String? description, String type) {
    final d = description?.trim() ?? '';
    if (d.isNotEmpty) return d;
    switch (type) {
      case 'earned':
      case 'visit':
        return 'Puntos por tu visita';
      case 'welcome_bonus':
        return 'Bono de bienvenida';
      case 'referral_referrer':
        return 'Invitaste a un amigo';
      case 'referral_referred':
        return 'Bono por venir invitado';
      case 'redeemed':
      case 'redemption':
        return 'Canje de premio';
      case 'reversal':
        return 'Devolución de puntos';
      case 'manual_adjust':
      case 'adjustment':
        return 'Ajuste de puntos';
      case 'bonus':
        return 'Bonificación';
      case 'expired':
        return 'Puntos vencidos';
      default:
        return 'Movimiento de puntos';
    }
  }

  static IconData _iconFor(String type, bool isEarned) {
    switch (type) {
      case 'earned':
      case 'visit':
        return Icons.content_cut_rounded;
      case 'welcome_bonus':
        return Icons.card_giftcard_rounded;
      case 'referral_referrer':
      case 'referral_referred':
        return Icons.person_add_rounded;
      case 'redeemed':
      case 'redemption':
        return Icons.redeem_rounded;
      case 'expired':
        return Icons.hourglass_disabled_rounded;
      case 'reversal':
        return Icons.undo_rounded;
      case 'manual_adjust':
      case 'adjustment':
        return Icons.tune_rounded;
      case 'bonus':
        return Icons.auto_awesome_rounded;
      default:
        return isEarned
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;
    }
  }
}
