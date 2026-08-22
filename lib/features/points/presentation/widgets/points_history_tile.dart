import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/core/utils/formatters.dart';

/// Fila de una transacción de puntos. Está pensada para vivir dentro de un
/// `LiquidSectionCard` (no dibuja su propia lámina): ícono en mini-vidrio,
/// descripción, tiempo relativo y el delta de puntos en verde/rojo.
class PointsHistoryTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  const PointsHistoryTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final points = (transaction['points'] as num?)?.toInt() ?? 0;
    final isEarned = points >= 0;
    final type = (transaction['type'] ?? '').toString();
    final description = _describe(transaction['description'] as String?, type);
    final createdAt = transaction['created_at'] != null
        ? DateTime.tryParse(transaction['created_at'].toString())
        : null;

    final accent = isEarned ? MonacoColors.monacoGreen : MonacoColors.destructive;
    final icon = _iconFor(type, isEarned);

    return Padding(
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
                if (createdAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    Formatters.relativeTime(createdAt),
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
            '${isEarned ? '+' : ''}$points',
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
    );
  }

  static String _describe(String? description, String type) {
    final d = description?.trim() ?? '';
    if (d.isNotEmpty) return d;
    switch (type) {
      case 'earned':
      case 'visit':
        return 'Puntos por tu visita';
      case 'redeemed':
      case 'redemption':
        return 'Canje de premio';
      case 'bonus':
        return 'Bonificación';
      case 'adjustment':
        return 'Ajuste de puntos';
      case 'expired':
        return 'Puntos vencidos';
      default:
        return 'Movimiento de puntos';
    }
  }

  static IconData _iconFor(String type, bool isEarned) {
    switch (type) {
      case 'redeemed':
      case 'redemption':
        return Icons.card_giftcard_rounded;
      case 'bonus':
        return Icons.auto_awesome_rounded;
      case 'expired':
        return Icons.timer_off_outlined;
      case 'adjustment':
        return Icons.tune_rounded;
      default:
        return isEarned
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;
    }
  }
}
