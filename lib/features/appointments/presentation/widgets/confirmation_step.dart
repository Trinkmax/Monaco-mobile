import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../../data/fechas.dart';
import '../../providers/booking_provider.dart';
import 'confirmacion_verde.dart';
import 'llegada_instrucciones.dart';
import 'turno_links.dart';

/// Pantalla post-reserva (réplica de `confirmation-step.tsx`): tilde, cuándo,
/// cómo registrar la llegada, detalle, calendario y "si no podés venir".
class ConfirmationStep extends StatelessWidget {
  final BookingWizardState state;
  final String clientName;
  final String clientPhone;
  final VoidCallback onVerTurno;
  final VoidCallback onIrMisTurnos;

  const ConfirmationStep({
    super.key,
    required this.state,
    required this.clientName,
    required this.clientPhone,
    required this.onVerTurno,
    required this.onIrMisTurnos,
  });

  @override
  Widget build(BuildContext context) {
    final boot = state.bootstrap!;
    final branch = boot.branch;
    final slot = state.selectedSlot;
    final date = state.selectedDate ?? boot.serverToday;
    final time = slot?.time ?? '--:--';
    final staffName = slot?.staffName ?? 'Por asignar';
    final servicios = state.selectedServices;
    final names = servicios.map((s) => s.name).join(' + ');
    final result = state.result;
    final pendientePago = result?.status == 'pending_payment';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        const _TildeConfirmado().liquidEnter(index: 0),
        const SizedBox(height: 14),
        Text(
          pendientePago ? 'Turno reservado' : 'Turno confirmado',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ).liquidEnter(index: 1),
        const SizedBox(height: 4),
        Text(
          pendientePago
              ? 'Queda pendiente de pago. Te mandamos los datos por WhatsApp.'
              : 'Te enviamos la confirmación por WhatsApp.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ).liquidEnter(index: 2),
        const SizedBox(height: 22),

        // ── CUÁNDO ──
        LiquidGlass(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          borderRadius: 26,
          tint: MonacoColors.monacoGreen,
          tintOpacity: 0.10,
          pressable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TU TURNO',
                style: TextStyle(
                  color: MonacoColors.monacoGreen.withValues(alpha: 0.9),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                time,
                style: const TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -1.6,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                Fechas.fechaLargaDeStr(date),
                style: const TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 14),
              Container(height: 0.6, color: Colors.white.withValues(alpha: 0.10)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.name,
                          style: const TextStyle(
                            color: MonacoColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (branch.address != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            branch.address!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (branch.hasCoordinates || branch.address != null) ...[
                    const SizedBox(width: 10),
                    LiquidPill(
                      onTap: () => abrirComoLlegar(
                        context,
                        latitude: branch.latitude,
                        longitude: branch.longitude,
                        address: branch.address,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.near_me_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Cómo llegar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ).liquidEnter(index: 3),
        const SizedBox(height: 14),

        ComoRegistrarLlegada(
          tieneCara: result?.clientHasFace,
          esNuevo: result?.clientIsNew ?? false,
        ).liquidEnter(index: 4),
        const SizedBox(height: 14),

        // ── DETALLE ──
        LiquidGlass(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          borderRadius: 22,
          tintOpacity: 0.07,
          pressable: false,
          showVignette: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LiquidAvatar(imageUrl: slot?.staffAvatarUrl, name: staffName, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TE ATIENDE',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          staffName,
                          style: const TextStyle(
                            color: MonacoColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Fila(
                label: 'Servicio',
                value: names.isEmpty ? '—' : names,
                trailing: state.totalPrice > 0 ? Fechas.moneda(state.totalPrice) : null,
              ),
              _Fila(label: 'Duración', value: Fechas.duracion(state.totalDuration)),
              _Fila(
                label: 'A nombre de',
                value: clientName.isEmpty ? '—' : clientName,
                sub: clientPhone.isEmpty ? null : clientPhone,
                last: true,
              ),
            ],
          ),
        ).liquidEnter(index: 5),
        const SizedBox(height: 12),

        LiquidPill(
          onTap: () => abrirUrlExterna(
            context,
            googleCalendarUrl(
              dateStr: date,
              startTime: time,
              durationMinutes: state.totalDuration,
              timezone: branch.timezone,
              branchName: branch.name,
              branchAddress: branch.address,
              servicesLabel: names,
              staffName: staffName,
            ),
          ),
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_rounded, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Agregar a Google Calendar',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ).liquidEnter(index: 6),
        const SizedBox(height: 18),

        // ── SI NO PODÉS VENIR ──
        LiquidGlass(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          borderRadius: 22,
          tintOpacity: 0.06,
          pressable: false,
          showVignette: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Si no podés venir',
                style: TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cancelá desde la app y le liberás el lugar a otra persona. Podés hacerlo hasta '
                '${Fechas.horas(boot.settings.cancellationMinHours)} antes del turno. El mismo link te llega por WhatsApp.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: LiquidButton(
                      onPressed: onVerTurno,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      child: const Text(
                        'Ver mi turno',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LiquidPill(
                      onTap: onIrMisTurnos,
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      child: const Center(
                        child: Text(
                          'Mis turnos',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).liquidEnter(index: 7),

        if (branch.phone != null) ...[
          const SizedBox(height: 22),
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => llamar(context, branch.phone!),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    const TextSpan(text: '¿Alguna duda? Llamanos al '),
                    TextSpan(
                      text: branch.phone,
                      style: const TextStyle(
                        color: MonacoColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white54,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ).liquidEnter(index: 8),
        ],
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final String? trailing;
  final bool last;

  const _Fila({
    required this.label,
    required this.value,
    this.sub,
    this.trailing,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07), width: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: MonacoColors.monacoGreen,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

/// Círculo de vidrio con el anillo y el tilde dibujándose en verde (versión
/// "en reposo" del velo).
class _TildeConfirmado extends StatefulWidget {
  const _TildeConfirmado();

  @override
  State<_TildeConfirmado> createState() => _TildeConfirmadoState();
}

class _TildeConfirmadoState extends State<_TildeConfirmado> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MonacoColors.monacoGreen.withValues(alpha: 0.22),
              MonacoColors.monacoGreen.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(color: MonacoColors.monacoGreen.withValues(alpha: 0.35), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: MonacoColors.monacoGreen.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: -6,
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => CustomPaint(
            painter: TildePainter(
              ringProgress: CurvedAnimation(
                parent: _ctrl,
                curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
              ).value,
              progress: CurvedAnimation(
                parent: _ctrl,
                curve: const Interval(0.45, 1, curve: Curves.easeOutCubic),
              ).value,
              color: MonacoColors.monacoGreen,
              strokeWidth: 5,
            ),
          ),
        ),
      ),
    );
  }
}
