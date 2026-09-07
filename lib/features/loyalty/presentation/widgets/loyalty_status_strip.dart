import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';

final _pts = NumberFormat.decimalPattern('es_AR');

/// Tira de pills debajo de la [MonacoCard]: el estado del programa en una
/// línea, y al final el atajo "Canjear" que antes vivía como botón de regalo
/// dentro de la tarjeta.
///
/// - `[workspace_premium] Oro · 7/9 visitas → Platinum` → `/categoria`
/// - `[hourglass] 120 pts vencen en 12 días` → `/points` (sólo si hay puntos
///   por vencer)
/// - `[warning ámbar] Tu nivel Oro vence en 5 días` → `/categoria` (sólo en
///   gracia)
/// - `[card_giftcard] Canjear` → `/rewards`
///
/// Con el programa apagado las pills de estado no existen (no hay categoría
/// ni vencimientos que informar) y queda sólo "Canjear": el Home no puede
/// perder su único acceso directo a Premios porque el dueño todavía no prendió
/// el programa.
class LoyaltyStatusStrip extends StatelessWidget {
  final LoyaltySummary summary;
  final VoidCallback? onCanjear;

  const LoyaltyStatusStrip({super.key, required this.summary, this.onCanjear});

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[];
    final s = summary;
    final tier = s.tier;

    if (s.programEnabled && tier != null) {
      final next = s.nextTier;
      final label = next == null
          ? '${tier.name} · nivel máximo'
          : '${tier.name} · ${s.visitsInWindow}/${next.minVisits} visitas → ${next.name}';
      pills.add(_Pill(
        icon: Icons.workspace_premium_rounded,
        label: label,
        semantica: next == null
            ? 'Categoría ${tier.name}, la más alta. Ver mi categoría'
            : 'Categoría ${tier.name}. ${s.visitsInWindow} de ${next.minVisits} visitas para ${next.name}. Ver mi categoría',
        onTap: () => context.push('/categoria'),
      ));

      if (s.points.expiringSoonPoints > 0) {
        // Cantidad y fecha del MISMO lote (el más próximo), como en el dorso
        // de la tarjeta, /points y el push: la suma de la ventana con la
        // cuenta regresiva del primer lote decía "200 pts vencen en 3 días"
        // cuando ese día vencían 100. La ventana sigue siendo el gate de
        // visibilidad de la pill.
        final soon = s.points.nextExpiryPoints;
        final dias = s.points.diasHastaVencimiento;
        if (soon > 0 && dias != null) {
          final cuando = dias <= 0
              ? 'hoy'
              : dias == 1
                  ? 'mañana'
                  : 'en $dias días';
          pills.add(_Pill(
            icon: Icons.hourglass_bottom_rounded,
            label: '${_pts.format(soon)} pts vencen $cuando',
            onTap: () => context.push('/points'),
          ));
        }
      }

      final grace = s.grace;
      if (grace != null) {
        final d = grace.daysLeft;
        final cuando = d <= 0
            ? 'hoy'
            : d == 1
                ? 'mañana'
                : 'en $d días';
        pills.add(_Pill(
          icon: Icons.warning_amber_rounded,
          label: 'Tu nivel ${tier.name} vence $cuando',
          tint: MonacoColors.warning,
          onTap: () => context.push('/categoria'),
        ));
      }
    }

    pills.add(_Pill(
      icon: Icons.card_giftcard_rounded,
      label: 'Canjear',
      semantica: 'Ver premios para canjear',
      onTap: onCanjear ?? () => context.go('/rewards'),
    ));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < pills.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            pills[i],
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? semantica;
  final Color? tint;
  final VoidCallback onTap;

  const _Pill({
    required this.icon,
    required this.label,
    this.semantica,
    this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = tint ?? Colors.white;
    return Semantics(
      button: true,
      label: semantica ?? label,
      child: ExcludeSemantics(
        child: LiquidPill(
          onTap: onTap,
          tint: tint,
          tintOpacity: tint == null ? 0.10 : 0.16,
          padding: const EdgeInsets.fromLTRB(11, 8, 13, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color.withValues(alpha: 0.95)),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: color.withValues(alpha: 0.95),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
