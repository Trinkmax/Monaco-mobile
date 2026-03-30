import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';

class OccupancyMiniCard extends StatelessWidget {
  final String branchName;
  final String occupancyLevel; // sin_espera | baja | media | alta
  final int etaMinutes;
  final bool isOpen;

  const OccupancyMiniCard({
    super.key,
    required this.branchName,
    required this.occupancyLevel,
    required this.etaMinutes,
    this.isOpen = true,
  });

  Color get _levelColor {
    if (!isOpen) return const Color(0xFF6B7280); // gris
    switch (occupancyLevel.toLowerCase()) {
      case 'alta':
        return const Color(0xFFEF4444); // red
      case 'media':
        return const Color(0xFFF59E0B); // amber
      case 'sin_espera':
        return const Color(0xFF22C55E); // green
      case 'baja':
      default:
        return const Color(0xFF22C55E); // green
    }
  }

  String get _levelLabel {
    if (!isOpen) return 'Cerrado';
    switch (occupancyLevel.toLowerCase()) {
      case 'alta':
        return 'Alta';
      case 'media':
        return 'Media';
      case 'sin_espera':
        return 'Sin espera';
      case 'baja':
      default:
        return 'Baja';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MonacoColors.divider.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Occupancy indicator
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _levelColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _levelColor.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _levelLabel,
                style: TextStyle(
                  color: _levelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Branch name
          Text(
            branchName,
            style: TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          // ETA
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 13,
                color: MonacoColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                etaMinutes > 0 && isOpen ? '~$etaMinutes min' : (isOpen ? 'Sin espera' : 'Cerrado'),
                style: TextStyle(
                  color: MonacoColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 400.ms,
        );
  }
}
