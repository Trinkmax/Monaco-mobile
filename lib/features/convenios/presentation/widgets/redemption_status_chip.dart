import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';

enum _ChipVariant { used, expired, expiresSoon, active }

/// Chip reutilizable para estados de canje. Se usa tanto en la lista "Mis canjes"
/// como en los cards del listado de convenios y el carrusel del home.
///
/// Prioridad visual (una sola chip visible):
///   used > expired > expiresSoon > active (oculto si [showActive] es false).
class RedemptionStatusChip extends StatelessWidget {
  /// Estado del canje del cliente ('issued' / 'used' / 'expired'), null si el
  /// cliente todavía no tiene un canje para este beneficio.
  final String? redemptionStatus;

  /// Fecha de vencimiento del beneficio (valid_until). Si falta, no se
  /// considera "vence pronto".
  final DateTime? validUntil;

  /// Si [redemptionStatus] es null y no hay vencimiento cercano, mostrar o no
  /// un chip neutro "Vigente". Por defecto `false` para no saturar los cards.
  final bool showActive;

  const RedemptionStatusChip({
    super.key,
    required this.redemptionStatus,
    this.validUntil,
    this.showActive = false,
  });

  _ChipVariant? _resolveVariant() {
    if (redemptionStatus == 'used') return _ChipVariant.used;

    final now = DateTime.now();
    final isExpiredWindow = validUntil != null && validUntil!.isBefore(now);
    if (isExpiredWindow || redemptionStatus == 'expired') {
      return _ChipVariant.expired;
    }

    if (validUntil != null) {
      final daysLeft = validUntil!.difference(now).inDays;
      if (daysLeft >= 0 && daysLeft <= 7) return _ChipVariant.expiresSoon;
    }

    if (showActive && redemptionStatus == 'issued') return _ChipVariant.active;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final variant = _resolveVariant();
    if (variant == null) return const SizedBox.shrink();

    final (label, icon, color) = switch (variant) {
      _ChipVariant.used => (
        'Ya canjeado',
        Icons.check_circle_rounded,
        MonacoColors.monacoGreen,
      ),
      _ChipVariant.expired => (
        'Vencido',
        Icons.schedule_rounded,
        MonacoColors.foregroundMuted,
      ),
      _ChipVariant.expiresSoon => (
        'Vence pronto',
        Icons.hourglass_bottom_rounded,
        MonacoColors.warning,
      ),
      _ChipVariant.active => (
        'Vigente',
        Icons.local_activity_rounded,
        MonacoColors.info,
      ),
    };

    return Semantics(
      label: 'Estado del beneficio: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.24),
              color.withValues(alpha: 0.10),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.38), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
