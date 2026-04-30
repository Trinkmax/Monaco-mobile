import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';

import '../data/appointment_model.dart';
import '../providers/appointments_provider.dart';
import 'cancel_dialog.dart';
import 'widgets/appointment_card.dart';
import 'widgets/empty_state.dart';

/// Pantalla principal del módulo de turnos del cliente.
///
/// Muestra dos pestañas (Próximos / Anteriores), permite refrescar pulldown
/// y abre el WebView de reservas desde el FAB "+ Reservar".
class MyAppointmentsScreen extends ConsumerStatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  ConsumerState<MyAppointmentsScreen> createState() =>
      _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends ConsumerState<MyAppointmentsScreen> {
  int _tab = 0; // 0 = próximos, 1 = anteriores

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // Si la sucursal no acepta turnos, mostramos un info-state. La ruta
    // probablemente no debería ser navegable, pero por las dudas se cubre.
    if (!auth.acceptsAppointments) {
      return LiquidAppBarScaffold(
        title: 'Mis turnos',
        showBackButton: true,
        body: AppointmentsEmptyState(
          icon: Icons.event_busy_rounded,
          title: 'Esta sucursal no toma turnos online',
          message:
              'Acercate y te atendemos por orden de llegada. Si querés, podés ver el estado de la cola desde la pantalla principal.',
          ctaLabel: 'Volver',
          onCta: () => context.pop(),
        ),
      );
    }

    final upcoming = ref.watch(upcomingAppointmentsProvider);
    final past = ref.watch(pastAppointmentsProvider);

    return LiquidAppBarScaffold(
      title: 'Mis turnos',
      showBackButton: true,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: LiquidSegmentedTabs(
                    labels: const ['Próximos', 'Anteriores'],
                    selectedIndex: _tab,
                    onChange: (i) => setState(() => _tab = i),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: Colors.white,
                    backgroundColor: MonacoColors.surface,
                    onRefresh: () async {
                      ref.invalidate(upcomingAppointmentsProvider);
                      ref.invalidate(pastAppointmentsProvider);
                      await Future.wait([
                        ref.read(upcomingAppointmentsProvider.future),
                        ref.read(pastAppointmentsProvider.future),
                      ]);
                    },
                    child: _tab == 0
                        ? _buildList(
                            upcoming,
                            isUpcoming: true,
                          )
                        : _buildList(
                            past,
                            isUpcoming: false,
                          ),
                  ),
                ),
              ],
            ),
          ),
          // FAB Reservar
          Positioned(
            right: 20,
            bottom: 28,
            child: SafeArea(
              child: LiquidButton(
                onPressed: () => context.push('/appointments/book'),
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
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
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    AsyncValue<List<Appointment>> async, {
    required bool isUpcoming,
  }) {
    return async.when(
      loading: () => const _LoadingState(),
      error: (e, _) => _ErrorState(
        error: e,
        onRetry: () {
          ref.invalidate(upcomingAppointmentsProvider);
          ref.invalidate(pastAppointmentsProvider);
        },
      ),
      data: (list) {
        if (list.isEmpty) {
          return AppointmentsEmptyState(
            icon: isUpcoming
                ? Icons.event_available_rounded
                : Icons.history_rounded,
            title: isUpcoming
                ? 'No tenés turnos próximos'
                : 'Todavía no hay historial',
            message: isUpcoming
                ? 'Reservá tu primer turno y te lo recordamos antes.'
                : 'Tus turnos pasados van a aparecer acá.',
            ctaLabel: isUpcoming ? 'Reservar turno' : null,
            onCta: isUpcoming
                ? () => context.push('/appointments/book')
                : null,
          );
        }

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final appt = list[i];
            return AppointmentCard(
              appointment: appt,
              isNext: isUpcoming && i == 0,
              onCancel: appt.canCancel ? () => _onCancel(appt) : null,
            ).liquidEnter(index: i);
          },
        );
      },
    );
  }

  Future<void> _onCancel(Appointment appt) async {
    if (appt.cancellationToken == null) return;

    final summary = '${appt.formattedDate} · ${appt.formattedTime}';
    final result = await showCancelAppointmentDialog(
      context,
      appointmentSummary: summary,
    );
    if (result == null || !mounted) return;

    final ok = await ref
        .read(appointmentsNotifierProvider.notifier)
        .cancelByToken(
          appt.cancellationToken!,
          reason: result.reason.isEmpty ? null : result.reason,
        );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Turno cancelado'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      final state = ref.read(appointmentsNotifierProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              state.error ?? 'No pudimos cancelar el turno. Intentá de nuevo.'),
          backgroundColor: const Color(0xFFE5484D),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

// ─── Loading & error states ──────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  Widget _shimmer({double height = 130}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white10);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
      children: [
        _shimmer(),
        const SizedBox(height: 12),
        _shimmer(),
        const SizedBox(height: 12),
        _shimmer(),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  bool get _isNetworkError {
    final s = error.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('clientexception') ||
        s.contains('connection') ||
        s.contains('timeout');
  }

  @override
  Widget build(BuildContext context) {
    final offline = _isNetworkError;
    final icon =
        offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded;
    final title = offline ? 'Sin conexión' : 'Algo salió mal';
    final message = offline
        ? 'Revisá tu conexión e intentá nuevamente.'
        : 'No pudimos cargar tus turnos. Probá en unos segundos.';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              border:
                  Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: LiquidPill(
            onTap: onRetry,
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Reintentar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}
