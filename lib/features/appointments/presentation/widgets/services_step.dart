import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../../data/booking_models.dart';
import '../../data/fechas.dart';

/// Paso 1 — "¿Qué te hacés?": multi-selección de servicios. El orden de
/// selección importa: el primero es el servicio principal del turno.
class ServicesStep extends StatelessWidget {
  final List<PublicService> services;
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;
  final String? welcomeMessage;
  final ClientUpcoming? upcoming;
  final String? firstName;

  const ServicesStep({
    super.key,
    required this.services,
    required this.selectedIds,
    required this.onToggle,
    this.welcomeMessage,
    this.upcoming,
    this.firstName,
  });

  @override
  Widget build(BuildContext context) {
    final saludo = (firstName != null && firstName!.isNotEmpty)
        ? '$firstName, ¿qué te hacés?'
        : '¿Qué te hacés?';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          saludo,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            height: 1.1,
          ),
        ).liquidEnter(index: 0),
        const SizedBox(height: 6),
        Text(
          welcomeMessage?.trim().isNotEmpty == true
              ? welcomeMessage!.trim()
              : 'Podés elegir más de uno. Sumamos la duración y te mostramos sólo horarios donde entre todo.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ).liquidEnter(index: 1),
        if (upcoming != null) ...[
          const SizedBox(height: 16),
          _TurnoExistente(upcoming: upcoming!).liquidEnter(index: 2),
        ],
        const SizedBox(height: 18),
        if (services.isEmpty)
          const LiquidEmptyState(
            icon: Icons.content_cut_rounded,
            title: 'No hay servicios disponibles en esta sucursal.',
            message: 'Probá más tarde o consultá en la barbería.',
            scrollable: false,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 32),
          )
        else
          for (var i = 0; i < services.length; i++) ...[
            _ServiceTile(
              service: services[i],
              selected: selectedIds.contains(services[i].id),
              orden: selectedIds.indexOf(services[i].id),
              onTap: () => onToggle(services[i].id),
            ).liquidEnter(index: 3 + i, stagger: 45),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final PublicService service;
  final bool selected;
  final int orden; // -1 si no está elegido
  final VoidCallback onTap;

  const _ServiceTile({
    required this.service,
    required this.selected,
    required this.orden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = MonacoColors.monacoGreen;
    return LiquidTapEffect(
      onTap: onTap,
      scaleTo: 0.975,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: LiquidTokens.swap,
        curve: LiquidTokens.curveSwap,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [accent.withValues(alpha: 0.26), accent.withValues(alpha: 0.08)]
                : [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.035)],
          ),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.16),
            width: selected ? 1.1 : 0.8,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 18,
                    spreadRadius: -6,
                    offset: const Offset(0, 8),
                  ),
                ]
              : LiquidTokens.pillLift(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      color: MonacoColors.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (service.durationMinutes != null) ...[
                        Icon(Icons.schedule_rounded, size: 13, color: Colors.white.withValues(alpha: 0.55)),
                        const SizedBox(width: 4),
                        Text(
                          Fechas.duracion(service.durationMinutes!),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        Fechas.moneda(service.price),
                        style: TextStyle(
                          color: selected ? accent : Colors.white.withValues(alpha: 0.9),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: LiquidTokens.swap,
              curve: LiquidTokens.curveSwap,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accent : Colors.transparent,
                border: Border.all(
                  color: selected ? accent : Colors.white.withValues(alpha: 0.35),
                  width: selected ? 0 : 1.2,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 10)]
                    : null,
              ),
              child: selected
                  ? (orden > 0
                      ? Center(
                          child: Text(
                            '${orden + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 17, color: Colors.white))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnoExistente extends StatelessWidget {
  final ClientUpcoming upcoming;
  const _TurnoExistente({required this.upcoming});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      borderRadius: 18,
      tint: MonacoColors.info,
      tintOpacity: 0.12,
      pressable: false,
      showVignette: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.event_available_rounded, size: 18, color: MonacoColors.info),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ya tenés un turno reservado',
                  style: TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${Fechas.fechaLargaDeStr(upcoming.date)} a las ${Fechas.hhmm(upcoming.time)}. '
                  'Podés sacar otro para un día distinto; para ese día ya está tomado tu lugar.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
