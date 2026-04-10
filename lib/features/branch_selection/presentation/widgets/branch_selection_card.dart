import 'package:flutter/material.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import '../../models/branch_with_distance.dart';

class BranchSelectionCard extends StatelessWidget {
  final BranchWithDistance branch;
  final VoidCallback onTap;

  const BranchSelectionCard({
    super.key,
    required this.branch,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MonacoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MonacoColors.border),
        ),
        child: Row(
          children: [
            // Indicador de estado
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: branch.isOpen
                    ? _occupancyColor(branch.occupancyLevel)
                    : MonacoColors.foregroundSubtle,
              ),
            ),
            const SizedBox(width: 14),

            // Info de la sucursal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          branch.name,
                          style: const TextStyle(
                            color: MonacoColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!branch.isOpen)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: MonacoColors.foregroundSubtle.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Cerrada',
                            style: TextStyle(
                              color: MonacoColors.foregroundSubtle,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (branch.address != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      branch.address!,
                      style: const TextStyle(
                        color: MonacoColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Distancia
                      if (branch.distanceKm != null) ...[
                        Icon(Icons.near_me_outlined,
                            size: 13, color: MonacoColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDistance(branch.distanceKm!),
                          style: const TextStyle(
                            color: MonacoColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      // Espera
                      if (branch.isOpen) ...[
                        Icon(Icons.schedule,
                            size: 13, color: MonacoColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          branch.waitingCount == 0
                              ? 'Sin espera'
                              : '~${branch.etaMinutes} min',
                          style: const TextStyle(
                            color: MonacoColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Barberos disponibles
                        Icon(Icons.content_cut,
                            size: 13, color: MonacoColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${branch.availableBarbers} libre${branch.availableBarbers != 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: MonacoColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: MonacoColors.foregroundSubtle,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  Color _occupancyColor(String level) {
    switch (level) {
      case 'sin_espera':
        return MonacoColors.occupancyLow;
      case 'baja':
        return MonacoColors.occupancyLow;
      case 'media':
        return MonacoColors.occupancyMedium;
      case 'alta':
        return MonacoColors.occupancyHigh;
      default:
        return MonacoColors.occupancyLow;
    }
  }
}
