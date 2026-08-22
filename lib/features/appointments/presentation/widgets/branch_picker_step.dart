import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../../data/booking_models.dart';

/// Selector de sucursales reservables. Aparece cuando la sucursal elegida en
/// la app atiende por orden de llegada (o no hay ninguna elegida).
class BranchPickerStep extends StatelessWidget {
  final List<MobileBranch> branches;
  final bool loading;
  final bool originalNotBookable;
  final String? originalBranchName;
  final ValueChanged<MobileBranch> onPick;

  const BranchPickerStep({
    super.key,
    required this.branches,
    required this.loading,
    required this.originalNotBookable,
    this.originalBranchName,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final titulo = originalNotBookable
        ? 'Esta sucursal atiende por orden de llegada.'
        : '¿Dónde querés reservar?';
    final sub = originalNotBookable
        ? 'Elegí una con turnos online:'
        : 'Estas sucursales toman turnos online.';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ).liquidEnter(index: 0),
        const SizedBox(height: 6),
        Text(
          sub,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ).liquidEnter(index: 1),
        const SizedBox(height: 18),
        if (loading) ...[
          for (var i = 0; i < 3; i++) ...[
            const LiquidSkeleton(height: 92),
            const SizedBox(height: 12),
          ],
        ] else if (branches.isEmpty)
          LiquidEmptyState(
            icon: Icons.event_busy_rounded,
            title: 'Por ahora no hay turnos online',
            message:
                'Ninguna sucursal está tomando turnos por la app en este momento. Acercate cuando quieras: te atendemos por orden de llegada.',
            scrollable: false,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 32),
          )
        else
          for (var i = 0; i < branches.length; i++) ...[
            _BranchTile(branch: branches[i], onTap: () => onPick(branches[i]))
                .liquidEnter(index: 2 + i),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _BranchTile extends StatelessWidget {
  final MobileBranch branch;
  final VoidCallback onTap;
  const _BranchTile({required this.branch, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final estadoColor = branch.openNow ? MonacoColors.monacoGreen : MonacoColors.foregroundSubtle;
    return LiquidGlass(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      borderRadius: 22,
      tintOpacity: 0.08,
      showVignette: false,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.8),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (branch.isTest) ...[
                      const SizedBox(width: 8),
                      const LiquidStatusPill(
                        label: 'PRUEBA',
                        color: MonacoColors.warning,
                        pulse: false,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                if (branch.address != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    branch.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (branch.hoursLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: estadoColor,
                          boxShadow: branch.openNow
                              ? [BoxShadow(color: estadoColor.withValues(alpha: 0.7), blurRadius: 6)]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          branch.hoursLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: estadoColor.withValues(alpha: 0.95),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.35), size: 24),
        ],
      ),
    );
  }
}
