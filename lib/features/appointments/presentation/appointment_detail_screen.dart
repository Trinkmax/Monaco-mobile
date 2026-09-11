import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/senas/presentation/widgets/arrepentimiento_link.dart';

import '../data/appointment_model.dart';
import '../data/fechas.dart';
import '../providers/appointments_provider.dart';
import '../providers/booking_provider.dart';
import 'cancel_dialog.dart';
import 'widgets/appointment_countdown.dart';
import 'widgets/appointment_status_chip.dart';
import 'widgets/llegada_instrucciones.dart';
import 'widgets/turno_links.dart';

/// Detalle de un turno: hora grande, fecha, sucursal + cómo llegar, barbero,
/// servicios y precio, estado, cómo registrar la llegada, calendario y
/// cancelar si aplica.
class AppointmentDetailScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  ConsumerState<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends ConsumerState<AppointmentDetailScreen> {
  bool _cancelando = false;

  Future<void> _cancelar(Appointment a, int minHours) async {
    final ok = await confirmCancelAppointment(
      context,
      summary: '${a.fechaLarga} · ${a.horaLabel}${a.branchName != null ? ' · ${a.branchName}' : ''}',
      cancellationMinHours: minHours,
      sena: a.deposit,
    );
    if (!ok || !mounted) return;
    setState(() => _cancelando = true);
    final err = await ref.read(appointmentActionsProvider).cancel(a.id);
    if (!mounted) return;
    setState(() => _cancelando = false);
    if (err == null) {
      showLiquidToast(context, 'Turno cancelado. Liberamos el horario.', tone: LiquidToastTone.success);
    } else {
      showLiquidToast(context, err, tone: LiquidToastTone.error, duration: const Duration(seconds: 4));
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/turnos');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(appointmentByIdProvider(widget.appointmentId));

    return LiquidAppBarScaffold(
      title: 'Tu turno',
      showBackButton: true,
      onBack: _back,
      body: async.when(
        loading: () => const LiquidSkeletonList(
          count: 3,
          itemHeight: 150,
          padding: EdgeInsets.fromLTRB(20, 16, 20, 60),
        ),
        error: (e, _) => LiquidErrorState(
          error: e,
          message: 'No pudimos cargar el turno. Probá en unos segundos.',
          onRetry: () => ref.invalidate(appointmentByIdProvider(widget.appointmentId)),
        ),
        data: (a) {
          if (a == null) {
            return LiquidEmptyState(
              icon: Icons.event_busy_rounded,
              title: 'No encontramos este turno',
              message: 'Puede que haya sido cancelado o que el link sea viejo.',
              ctaLabel: 'Ir a mis turnos',
              onCta: () => context.go('/turnos'),
            );
          }
          return _Detalle(
            a: a,
            cancelando: _cancelando,
            onCancelar: (minHours) => _cancelar(a, minHours),
            onRefresh: () async {
              ref.invalidate(appointmentByIdProvider(widget.appointmentId));
              await ref.read(appointmentByIdProvider(widget.appointmentId).future);
            },
          );
        },
      ),
    );
  }
}

class _Detalle extends ConsumerWidget {
  final Appointment a;
  final bool cancelando;
  final ValueChanged<int> onCancelar;
  final Future<void> Function() onRefresh;

  const _Detalle({
    required this.a,
    required this.cancelando,
    required this.onCancelar,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minHours = ref.watch(cancellationMinHoursProvider(a.branchSlug));
    final now = DateTime.now().toUtc();
    final puedeCancelar = a.canCancel(minHours: minHours, now: now);
    final cerradoPorVentana = a.status.isCancellable && !puedeCancelar;
    final accent = AppointmentStatusChip.colorFor(a.status);
    final activo = a.status.isActive;
    final price = a.totalPrice;

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: MonacoColors.surface,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
        children: [
          // ── Hero: hora + fecha + estado ──
          LiquidGlass(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            borderRadius: 26,
            tint: activo ? accent : Colors.white,
            tintOpacity: activo ? 0.11 : 0.06,
            pressable: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppointmentStatusChip(status: a.status, compact: false),
                    const Spacer(),
                    if (activo) AppointmentCountdown(appointment: a, pill: true),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  a.horaLabel,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  a.fechaLarga,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  '${a.etiquetaDia(now: now)} · ${Fechas.duracion(a.durationMinutes)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ).liquidEnter(index: 0),
          const SizedBox(height: 12),

          // ── Sucursal ──
          LiquidGlass(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            borderRadius: 22,
            tintOpacity: 0.07,
            pressable: false,
            showVignette: false,
            child: Row(
              children: [
                _IconBox(icon: Icons.storefront_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.branchName ?? 'Sucursal',
                        style: const TextStyle(
                          color: MonacoColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (a.branchAddress != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          a.branchAddress!,
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
                if (a.canOpenMaps) ...[
                  const SizedBox(width: 8),
                  LiquidPill(
                    onTap: () => abrirComoLlegar(
                      context,
                      latitude: a.branchLatitude,
                      longitude: a.branchLongitude,
                      address: a.branchAddress,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.near_me_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Cómo llegar',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ).liquidEnter(index: 1),
          const SizedBox(height: 12),

          // ── Barbero + servicios ──
          LiquidGlass(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            borderRadius: 22,
            tintOpacity: 0.07,
            pressable: false,
            showVignette: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    LiquidAvatar(imageUrl: a.barberAvatarUrl, name: a.barberName ?? '', size: 44),
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
                            (a.barberName != null && a.barberName!.trim().isNotEmpty)
                                ? a.barberName!
                                : 'Por asignar',
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
                Container(height: 0.6, color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 10),
                for (var i = 0; i < a.services.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(Icons.content_cut_rounded, size: 14, color: Colors.white.withValues(alpha: 0.55)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (a.services[i].name ?? '').trim().isEmpty ? 'Servicio' : a.services[i].name!,
                            style: const TextStyle(
                              color: MonacoColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (a.services[i].price != null)
                          Text(
                            Fechas.moneda(a.services[i].price!),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (a.services.isEmpty)
                  Text(
                    'Servicio',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5),
                  ),
                if (price != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        Fechas.moneda(price),
                        style: const TextStyle(
                          color: MonacoColors.monacoGreen,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ).liquidEnter(index: 2),

          // ── Seña ──
          if (a.deposit != null && a.deposit!.plataDelLocal) ...[
            const SizedBox(height: 12),
            _SenaPagada(sena: a.deposit!, total: price).liquidEnter(index: 3),
          ],

          if (activo && !a.status.isAtShop) ...[
            const SizedBox(height: 12),
            const ComoRegistrarLlegada(tieneCara: null).liquidEnter(index: 3),
          ],

          if (activo) ...[
            const SizedBox(height: 12),
            LiquidPill(
              onTap: () => abrirUrlExterna(
                context,
                googleCalendarUrl(
                  dateStr: a.dateStr,
                  startTime: a.startTime,
                  durationMinutes: a.durationMinutes,
                  timezone: a.branchTimezone,
                  branchName: a.branchName ?? 'Monaco',
                  branchAddress: a.branchAddress,
                  servicesLabel: a.servicesLabel,
                  staffName: a.barberName ?? 'tu barbero',
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
            ).liquidEnter(index: 4),
          ],

          // ── Cancelar ──
          if (puedeCancelar) ...[
            const SizedBox(height: 20),
            Text(
              'Podés cancelar hasta ${Fechas.horas(minHours)} antes del turno. El horario se libera para otro cliente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ).liquidEnter(index: 5),
            const SizedBox(height: 10),
            Opacity(
              opacity: cancelando ? 0.6 : 1,
              child: LiquidPill(
                onTap: cancelando ? null : () => onCancelar(minHours),
                tint: MonacoColors.destructive,
                tintOpacity: 0.16,
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (cancelando)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: MonacoColors.destructive),
                      )
                    else
                      const Icon(Icons.close_rounded, size: 18, color: MonacoColors.destructive),
                    const SizedBox(width: 8),
                    Text(
                      cancelando ? 'Cancelando…' : 'Cancelar mi turno',
                      style: const TextStyle(
                        color: MonacoColors.destructive,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ).liquidEnter(index: 6),
          ] else if (cerradoPorVentana) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: MonacoColors.warning.withValues(alpha: 0.10),
                border: Border.all(color: MonacoColors.warning.withValues(alpha: 0.35), width: 0.8),
              ),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    const TextSpan(text: 'Ya no se puede cancelar desde la app: la cancelación cierra '),
                    TextSpan(
                      text: '${Fechas.horas(minHours)} antes',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const TextSpan(text: ' del turno. Si no vas a poder venir, avisanos'),
                    if (a.branchPhone != null) ...[
                      const TextSpan(text: ' al '),
                      TextSpan(
                        text: a.branchPhone,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ],
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ).liquidEnter(index: 5),
          ] else if (a.status == AppointmentStatus.cancelled) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Este turno fue cancelado.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
            ).liquidEnter(index: 5),
          ] else if (a.status == AppointmentStatus.completed) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Este turno ya fue completado. ¡Gracias por venir!',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
            ).liquidEnter(index: 5),
          ],

          if (a.branchPhone != null) ...[
            const SizedBox(height: 22),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => llamar(context, a.branchPhone!),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      const TextSpan(text: '¿Necesitás ayuda? Llamá al '),
                      TextSpan(
                        text: a.branchPhone,
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
            ).liquidEnter(index: 7),
          ],
        ],
      ),
    );
  }
}

/// La seña de este turno: cuánto se pagó, cuánto queda para el local y el
/// **Botón de arrepentimiento**.
///
/// El link va acá y no sólo en la hoja de antes de pagar porque los 10 días
/// del art. 1110 CCyC empiezan a correr con el pago: el detalle del turno es
/// la única pantalla a la que el cliente vuelve durante esos 10 días.
class _SenaPagada extends StatelessWidget {
  final AppointmentDeposit sena;
  final num? total;

  const _SenaPagada({required this.sena, required this.total});

  @override
  Widget build(BuildContext context) {
    final t = total;
    final resto = (t != null && t > sena.amount) ? t - sena.amount : null;

    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      borderRadius: 22,
      tintOpacity: 0.07,
      pressable: false,
      showVignette: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBox(icon: Icons.verified_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEÑA PAGADA',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Fechas.moneda(sena.amount),
                      style: const TextStyle(
                        color: MonacoColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (resto != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'En el local pagás los ${Fechas.moneda(resto)} que faltan.',
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
            ],
          ),
          const ArrepentimientoLink(),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  const _IconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
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
      child: Icon(icon, color: Colors.white, size: 19),
    );
  }
}
