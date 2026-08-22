import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/location/location_service.dart';

import '../../models/branch_with_distance.dart';

/// Tarjeta de sucursal del selector: nombre, dirección, distancia, estado en
/// vivo (mismos colores y etiquetas que `OccupancyMiniCard` / el hero de
/// detalle), chip "Toma turnos online" y marca de sucursal de prueba.
class BranchCard extends StatelessWidget {
  final BranchWithDistance branch;
  final bool selected;
  final VoidCallback onTap;

  const BranchCard({
    super.key,
    required this.branch,
    required this.selected,
    required this.onTap,
  });

  Color get _levelColor {
    if (branch.isEffectivelyClosed) return MonacoColors.occupancyClosed;
    switch (_effectiveLevel) {
      case 'alta':
        return MonacoColors.occupancyHigh;
      case 'media':
        return MonacoColors.occupancyMedium;
      case 'baja':
        return MonacoColors.occupancyLow;
      case 'sin_espera':
      default:
        return MonacoColors.occupancyNone;
    }
  }

  String get _levelLabel {
    if (branch.isEffectivelyClosed) return 'Cerrado';
    switch (_effectiveLevel) {
      case 'alta':
        return 'Alta demanda';
      case 'media':
        return 'Movimiento';
      case 'baja':
        return 'Espera corta';
      case 'sin_espera':
      default:
        return 'Sin espera';
    }
  }

  /// Si el nivel dice "sin espera" pero hay gente esperando, el dato está
  /// desfasado: mostramos "Espera corta" para no contradecir la fila.
  String get _effectiveLevel {
    final lvl = branch.occupancyLevel.toLowerCase();
    if (lvl == 'sin_espera' && branch.waitingCount > 0) return 'baja';
    return lvl;
  }

  String get _detail {
    if (branch.isEffectivelyClosed) return 'Volvemos pronto';
    final parts = <String>[];
    final n = branch.totalBarbers;
    parts.add(n == 1 ? '1 barbero atendiendo' : '$n barberos atendiendo');
    if (branch.waitingCount > 0) {
      parts.add(
        branch.waitingCount == 1
            ? '1 persona en espera'
            : '${branch.waitingCount} en espera',
      );
    }
    if (branch.etaMinutes > 0) parts.add('aprox. ${branch.etaMinutes} min');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor;
    final closed = branch.isEffectivelyClosed;

    return Semantics(
      button: true,
      selected: selected,
      label: '${branch.name}, $_levelLabel',
      child: LiquidGlass(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        borderRadius: LiquidTokens.radiusGroup,
        tint: selected ? MonacoColors.monacoGreen : null,
        tintOpacity: selected ? 0.16 : 0.09,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              branch.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MonacoColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                          ),
                          if (branch.isTest) ...[
                            const SizedBox(width: 8),
                            const _Tag(
                              label: 'PRUEBA',
                              icon: Icons.science_rounded,
                              color: MonacoColors.deepViolet,
                            ),
                          ],
                        ],
                      ),
                      if ((branch.address ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.place_rounded,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                branch.address!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (selected)
                      const _SelectedMark()
                    else if (branch.distanceKm != null)
                      _DistancePill(km: branch.distanceKm!),
                    if (selected && branch.distanceKm != null) ...[
                      const SizedBox(height: 6),
                      _DistancePill(km: branch.distanceKm!),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Estado en vivo ──
            Row(
              children: [
                LiquidStatusPill(
                  label: _levelLabel,
                  color: color,
                  pulse: !closed,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: closed ? 0.4 : 0.62,
                      ),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (branch.acceptsAppointments) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  _Tag(
                    label: 'Toma turnos online',
                    icon: Icons.event_available_rounded,
                    color: MonacoColors.monacoGreen,
                    uppercase: false,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DistancePill extends StatelessWidget {
  final double km;
  const _DistancePill({required this.km});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.near_me_rounded,
            size: 12,
            color: Colors.white.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 4),
          Text(
            LocationService.formatDistance(km),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedMark extends StatelessWidget {
  const _SelectedMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MonacoColors.monacoGreen,
            MonacoColors.monacoGreenDeep.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: MonacoColors.monacoGreen.withValues(alpha: 0.45),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool uppercase;

  const _Tag({
    required this.label,
    required this.icon,
    required this.color,
    this.uppercase = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.26),
            color.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            uppercase ? label.toUpperCase() : label,
            style: TextStyle(
              color: Colors.white,
              fontSize: uppercase ? 10 : 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: uppercase ? 0.8 : 0,
            ),
          ),
        ],
      ),
    );
  }
}
