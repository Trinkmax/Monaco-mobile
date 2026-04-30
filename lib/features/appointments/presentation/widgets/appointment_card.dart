import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../../data/appointment_model.dart';
import 'appointment_status_chip.dart';

/// Tarjeta de turno — muestra todos los datos relevantes y dos acciones:
///  - "Cómo llegar" (si la sucursal tiene lat/lng o address)
///  - "Cancelar" (si [Appointment.canCancel])
class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool isNext;
  final VoidCallback? onCancel;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.isNext = false,
    this.onCancel,
  });

  static final _currency = NumberFormat.currency(
    locale: 'es_AR',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final price = a.totalPrice;

    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      borderRadius: 22,
      tintOpacity: 0.07,
      pressable: false,
      showVignette: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header pill row ──────────────────────────────────────────────
          Row(
            children: [
              if (isNext)
                const _NextPill()
              else
                AppointmentStatusChip(status: a.status),
              const Spacer(),
              if (price != null)
                Text(
                  _currency.format(price),
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Date + Time ─────────────────────────────────────────────────
          Text(
            a.formattedDate,
            style: const TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: Colors.white.withOpacity(0.6),
              ),
              const SizedBox(width: 5),
              Text(
                '${a.formattedTime}  ·  ${a.durationMinutes} min',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Service + Barber + Branch ────────────────────────────────────
          _InfoRow(
            icon: Icons.content_cut_rounded,
            label: a.servicesLabel,
          ),
          if (a.barberName != null && a.barberName!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'con ${a.barberName}',
            ),
          ],
          if (a.branchName != null && a.branchName!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.place_outlined,
              label: a.branchName!,
            ),
          ],
          if (a.notes != null && a.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Text(
                a.notes!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          // ── Actions ──────────────────────────────────────────────────────
          if (_hasAnyAction(a)) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (_canOpenMaps(a)) ...[
                  Expanded(
                    child: _ActionPill(
                      icon: Icons.map_outlined,
                      label: 'Cómo llegar',
                      onTap: () => _openMaps(a),
                    ),
                  ),
                  if (a.canCancel) const SizedBox(width: 10),
                ],
                if (a.canCancel)
                  Expanded(
                    child: _ActionPill(
                      icon: Icons.close_rounded,
                      label: 'Cancelar',
                      destructive: true,
                      onTap: onCancel,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _hasAnyAction(Appointment a) => _canOpenMaps(a) || a.canCancel;

  bool _canOpenMaps(Appointment a) {
    final hasLatLng = a.branchLatitude != null && a.branchLongitude != null;
    final hasAddress =
        a.branchAddress != null && a.branchAddress!.trim().isNotEmpty;
    return hasLatLng || hasAddress;
  }

  Future<void> _openMaps(Appointment a) async {
    Uri? uri;
    if (a.branchLatitude != null && a.branchLongitude != null) {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${a.branchLatitude},${a.branchLongitude}');
    } else if (a.branchAddress != null) {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(a.branchAddress!)}');
    }
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─── Helpers privados ─────────────────────────────────────────────────────────

class _NextPill extends StatelessWidget {
  const _NextPill();

  @override
  Widget build(BuildContext context) {
    const accent = MonacoColors.monacoGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(0.28),
            accent.withOpacity(0.12),
          ],
        ),
        border: Border.all(color: accent.withOpacity(0.5), width: 0.8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 12, color: accent),
          SizedBox(width: 5),
          Text(
            'PRÓXIMO',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.6)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.86),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  const _ActionPill({
    required this.icon,
    required this.label,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        destructive ? const Color(0xFFE5484D) : Colors.white;
    return LiquidPill(
      onTap: onTap,
      tint: accent,
      tintOpacity: destructive ? 0.16 : 0.10,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
