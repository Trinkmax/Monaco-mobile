import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../../data/appointment_model.dart';
import '../../data/fechas.dart';
import 'appointment_countdown.dart';
import 'appointment_status_chip.dart';
import 'turno_links.dart';

/// Tarjeta de turno. `hero` = la versión destacada del próximo turno (hora
/// grande + cuenta regresiva viva); si no, la compacta de la lista. Tocar la
/// tarjeta abre el detalle (`onTap`).
class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool hero;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.hero = false,
    this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return hero ? _Hero(a: appointment, onTap: onTap, onCancel: onCancel) : _Compacta(a: appointment, onTap: onTap);
  }
}

class _Hero extends StatelessWidget {
  final Appointment a;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  const _Hero({required this.a, required this.onTap, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final accent = a.status.isAtShop ? AppointmentStatusChip.colorFor(a.status) : MonacoColors.monacoGreen;
    final price = a.totalPrice;
    return LiquidGlass(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      borderRadius: 26,
      tint: accent,
      tintOpacity: 0.11,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                a.status.isAtShop ? a.status.label.toUpperCase() : 'PRÓXIMO TURNO',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.95),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              AppointmentCountdown(appointment: a, pill: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                a.horaLabel,
                style: const TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -1.6,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    a.etiquetaDia(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MonacoColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              LiquidAvatar(imageUrl: a.barberAvatarUrl, name: a.barberName ?? '', size: 40, tint: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.servicesLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MonacoColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (a.barberName != null && a.barberName!.trim().isNotEmpty) 'con ${a.barberName}',
                        if (a.branchName != null) a.branchName!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (price != null) ...[
                const SizedBox(width: 8),
                Text(
                  Fechas.moneda(price),
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (a.canOpenMaps)
                Expanded(
                  child: _ActionPill(
                    icon: Icons.near_me_rounded,
                    label: 'Cómo llegar',
                    onTap: () => abrirComoLlegar(
                      context,
                      latitude: a.branchLatitude,
                      longitude: a.branchLongitude,
                      address: a.branchAddress,
                    ),
                  ),
                ),
              if (a.canOpenMaps) const SizedBox(width: 10),
              Expanded(
                child: _ActionPill(
                  icon: Icons.chevron_right_rounded,
                  label: 'Ver detalle',
                  onTap: onTap,
                  primary: true,
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(width: 10),
                _ActionPill(
                  icon: Icons.close_rounded,
                  label: 'Cancelar',
                  destructive: true,
                  onTap: onCancel,
                  compact: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Compacta extends StatelessWidget {
  final Appointment a;
  final VoidCallback? onTap;
  const _Compacta({required this.a, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final apagado = !a.status.isActive;
    final price = a.totalPrice;
    return LiquidGlass(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      borderRadius: 22,
      tintOpacity: apagado ? 0.05 : 0.08,
      showVignette: false,
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: apagado ? 0.04 : 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
            ),
            child: Column(
              children: [
                Text(
                  Fechas.diasAbrevMayus[a.dayOfWeek],
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  Fechas.parseDate(a.dateStr).day.toString(),
                  style: TextStyle(
                    color: apagado ? Colors.white.withValues(alpha: 0.6) : MonacoColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: -0.6,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  Fechas.meses[Fechas.parseDate(a.dateStr).month - 1].substring(0, 3),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      a.horaLabel,
                      style: TextStyle(
                        color: apagado ? Colors.white.withValues(alpha: 0.7) : MonacoColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppointmentStatusChip(status: a.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  a.servicesLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: apagado ? 0.65 : 0.88),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (a.barberName != null && a.barberName!.trim().isNotEmpty) 'con ${a.barberName}',
                    if (a.branchName != null) a.branchName!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (price != null)
                Text(
                  Fechas.moneda(price),
                  style: TextStyle(
                    color: apagado ? Colors.white.withValues(alpha: 0.6) : MonacoColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(height: 6),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.35), size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final bool primary;
  final bool compact;

  const _ActionPill({
    required this.icon,
    required this.label,
    this.onTap,
    this.destructive = false,
    this.primary = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = destructive
        ? MonacoColors.destructive
        : primary
            ? MonacoColors.monacoGreen
            : Colors.white;
    return LiquidPill(
      onTap: onTap,
      tint: accent,
      tintOpacity: destructive ? 0.16 : (primary ? 0.18 : 0.10),
      borderRadius: 14,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 12, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: destructive ? accent : Colors.white),
          if (!compact) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: destructive ? accent : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
