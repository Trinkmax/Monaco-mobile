import 'package:flutter/material.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import '../../models/org_with_branches.dart';

class OrgSelectionCard extends StatelessWidget {
  final OrgWithBranches org;
  final VoidCallback onTap;

  const OrgSelectionCard({
    super.key,
    required this.org,
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
            // Logo o ícono de la org
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: MonacoColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: org.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        org.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.storefront,
                          color: MonacoColors.gold,
                          size: 24,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.storefront,
                      color: MonacoColors.gold,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 14),

            // Info de la org
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    org.name,
                    style: const TextStyle(
                      color: MonacoColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Cantidad de sucursales
                      Icon(Icons.location_on_outlined,
                          size: 13, color: MonacoColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${org.branchCount} sucursal${org.branchCount != 1 ? 'es' : ''}',
                        style: const TextStyle(
                          color: MonacoColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      // Distancia mínima
                      if (org.minDistanceKm != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.near_me_outlined,
                            size: 13, color: MonacoColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDistance(org.minDistanceKm!),
                          style: const TextStyle(
                            color: MonacoColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
}
