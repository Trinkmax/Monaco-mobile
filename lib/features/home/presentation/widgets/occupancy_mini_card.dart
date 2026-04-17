import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

/// Mini card de ocupación estilo iOS 26 — glass + LED pill + barra de
/// segmentos. Los labels y colores están sincronizados con el hero de
/// branch_detail_screen.dart.
class OccupancyMiniCard extends StatelessWidget {
  final String branchName;
  final String occupancyLevel; // sin_espera | baja | media | alta
  final bool isOpen;
  final VoidCallback? onTap;

  const OccupancyMiniCard({
    super.key,
    required this.branchName,
    required this.occupancyLevel,
    this.isOpen = true,
    this.onTap,
  });

  Color get _levelColor {
    if (!isOpen) return const Color(0xFF6B6B6B);
    switch (occupancyLevel.toLowerCase()) {
      case 'alta':
        return const Color(0xFFEF4444);
      case 'media':
        return const Color(0xFFF59E0B);
      case 'baja':
        return const Color(0xFF84CC16);
      case 'sin_espera':
      default:
        return LiquidTokens.monacoGreen;
    }
  }

  String get _levelLabel {
    if (!isOpen) return 'Cerrado';
    switch (occupancyLevel.toLowerCase()) {
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

  int get _filledSegments {
    if (!isOpen) return 0;
    switch (occupancyLevel.toLowerCase()) {
      case 'alta':
        return 4;
      case 'media':
        return 3;
      case 'baja':
        return 2;
      case 'sin_espera':
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor;

    return LiquidGlass(
      width: 160,
      height: 128,
      padding: const EdgeInsets.all(14),
      borderRadius: 22,
      tint: color,
      tintOpacity: 0.09,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiquidStatusPill(
            label: _levelLabel,
            color: color,
            pulse: isOpen,
            compact: true,
          ),
          const SizedBox(height: 12),
          Text(
            branchName,
            style: const TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: List.generate(4, (i) {
              final filled = i < _filledSegments;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 3 ? 3 : 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 4,
                    decoration: BoxDecoration(
                      color: filled
                          ? color.withOpacity(0.9)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: filled
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.5),
                                blurRadius: 6,
                              )
                            ]
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
