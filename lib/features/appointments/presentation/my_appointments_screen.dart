import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../data/appointment_model.dart';
import '../providers/appointments_provider.dart';
import '../providers/booking_provider.dart';
import 'cancel_dialog.dart';
import 'widgets/appointment_card.dart';

/// Pestaña "Turnos" del dock: Próximos / Anteriores, próximo turno destacado
/// con cuenta regresiva, pull-to-refresh y FAB "Reservar". Sin botón atrás
/// (vive dentro del shell) y con padding inferior para el dock.
class MyAppointmentsScreen extends ConsumerStatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  ConsumerState<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends ConsumerState<MyAppointmentsScreen> {
  int _tab = 0;

  Future<void> _refresh() async {
    ref.invalidate(upcomingAppointmentsProvider);
    ref.invalidate(pastAppointmentsProvider);
    await Future.wait([
      ref.read(upcomingAppointmentsProvider.future),
      ref.read(pastAppointmentsProvider.future),
    ]);
  }

  Future<void> _cancelar(Appointment a) async {
    final minHours = ref.read(cancellationMinHoursProvider(a.branchSlug));
    final ok = await confirmCancelAppointment(
      context,
      summary: '${a.fechaLarga} · ${a.horaLabel}${a.branchName != null ? ' · ${a.branchName}' : ''}',
      cancellationMinHours: minHours,
    );
    if (!ok || !mounted) return;
    final err = await ref.read(appointmentActionsProvider).cancel(a.id);
    if (!mounted) return;
    if (err == null) {
      showLiquidToast(
        context,
        'Turno cancelado. Liberamos el horario.',
        tone: LiquidToastTone.success,
      );
    } else {
      showLiquidToast(context, err, tone: LiquidToastTone.error, duration: const Duration(seconds: 4));
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(upcomingAppointmentsProvider);
    final past = ref.watch(pastAppointmentsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: MonacoColors.background,
      extendBody: true,
      body: LiquidBackdrop(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Turnos',
                          style: TextStyle(
                            color: MonacoColors.textPrimary,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.1,
                          ),
                        ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.05, end: 0, duration: 500.ms),
                        const SizedBox(height: 4),
                        Text(
                          'Tus reservas, al toque.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                        const SizedBox(height: 16),
                        LiquidSegmentedTabs(
                          labels: const ['Próximos', 'Anteriores'],
                          selectedIndex: _tab,
                          onChange: (i) => setState(() => _tab = i),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: Colors.white,
                      backgroundColor: MonacoColors.surface,
                      edgeOffset: 8,
                      onRefresh: _refresh,
                      child: _tab == 0 ? _lista(upcoming, upcoming: true) : _lista(past, upcoming: false),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 20,
                bottom: 92 + bottomInset,
                child: LiquidButton(
                  onPressed: () => context.push('/turnos/reservar'),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Reservar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.2, end: 0, duration: 400.ms),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lista(AsyncValue<List<Appointment>> async, {required bool upcoming}) {
    return async.when(
      loading: () => const LiquidSkeletonList(
        count: 3,
        itemHeight: 120,
        padding: EdgeInsets.fromLTRB(20, 16, 20, 120),
      ),
      error: (e, _) => LiquidErrorState(
        error: e,
        message: 'No pudimos cargar tus turnos. Probá en unos segundos.',
        onRetry: _refresh,
      ),
      data: (list) {
        if (list.isEmpty) {
          return LiquidEmptyState(
            icon: upcoming ? Icons.event_available_rounded : Icons.history_rounded,
            title: upcoming ? 'No tenés turnos próximos' : 'Todavía no hay historial',
            message: upcoming
                ? 'Reservá tu próximo turno en un minuto: elegís el servicio, el día y la hora, y listo.'
                : 'Tus turnos pasados van a aparecer acá.',
            ctaLabel: upcoming ? 'Reservar turno' : null,
            onCta: upcoming ? () => context.push('/turnos/reservar') : null,
            padding: const EdgeInsets.fromLTRB(32, 56, 32, 140),
          );
        }
        final now = DateTime.now().toUtc();
        int heroIdx = -1;
        if (upcoming) {
          heroIdx = list.indexWhere((a) => a.isLive(now: now));
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final a = list[i];
            final minHours = ref.watch(cancellationMinHoursProvider(a.branchSlug));
            final puedeCancelar = upcoming && a.canCancel(minHours: minHours, now: now);
            return AppointmentCard(
              appointment: a,
              hero: i == heroIdx,
              onTap: () => context.push('/turnos/${a.id}'),
              onCancel: (i == heroIdx && puedeCancelar) ? () => _cancelar(a) : null,
            ).liquidEnter(index: i);
          },
        );
      },
    );
  }
}
