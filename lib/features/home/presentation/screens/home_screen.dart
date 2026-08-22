import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/branch/selected_branch_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/features/appointments/data/appointment_model.dart';
import 'package:monaco_mobile/features/appointments/data/fechas.dart';
import 'package:monaco_mobile/features/appointments/presentation/widgets/appointment_countdown.dart';
import 'package:monaco_mobile/features/appointments/presentation/widgets/turno_links.dart';
import 'package:monaco_mobile/features/appointments/providers/appointments_provider.dart';
import 'package:monaco_mobile/features/appointments/providers/booking_provider.dart';
import 'package:monaco_mobile/features/convenios/presentation/widgets/convenio_card.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/home/presentation/widgets/occupancy_mini_card.dart';
import 'package:monaco_mobile/features/home/presentation/widgets/points_card.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';
import 'package:monaco_mobile/features/points/providers/points_provider.dart';
import 'package:monaco_mobile/features/reviews/providers/reviews_provider.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final billboardProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase
      .from('billboard_items')
      .select()
      .eq('is_active', true)
      .order('sort_order');
  return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
});

// ── Screen ─────────────────────────────────────────────────────────────────

/// Inicio. Orden: saludo + fecha, pill de sucursal, **tu próximo turno** (o el
/// CTA para reservar si la sucursal toma turnos online), puntos, reseñas
/// pendientes, sucursales en vivo, cartelera, convenios y accesos rápidos.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final points = ref.watch(globalPointsProvider);
    final reviews = ref.watch(pendingReviewsProvider);
    final branches = ref.watch(branchSignalsProvider);
    final billboard = ref.watch(billboardProvider);
    final convenios = ref.watch(conveniosProvider);
    final selectedBranchName = ref.watch(selectedBranchNameProvider);
    final nextAppointment = ref.watch(nextAppointmentProvider);

    // ¿La sucursal elegida toma turnos online? El server lo resuelve (modo +
    // `is_enabled`); mientras no contesta caemos al modo guardado en la app.
    final bookable =
        ref.watch(selectedBranchBookableProvider) ?? auth.acceptsAppointments;

    final firstName = auth.firstName;
    final saludo = firstName.isEmpty ? 'Hola' : 'Hola, $firstName';
    final today = Fechas.fechaLarga(DateTime.now());

    return Scaffold(
      backgroundColor: MonacoColors.background,
      extendBody: true,
      body: LiquidBackdrop(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: Colors.white,
            backgroundColor: MonacoColors.surface,
            onRefresh: () async {
              ref.invalidate(globalPointsProvider);
              ref.invalidate(pendingReviewsProvider);
              ref.invalidate(branchSignalsProvider);
              ref.invalidate(billboardProvider);
              ref.invalidate(conveniosProvider);
              ref.invalidate(upcomingAppointmentsProvider);
              ref.invalidate(mobileBranchesProvider);
              await Future.wait([
                ref.read(globalPointsProvider.future),
                ref.read(upcomingAppointmentsProvider.future),
              ]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  _Header(saludo: saludo, date: today),
                  const SizedBox(height: 14),

                  // ── Sucursal ──
                  _BranchPill(
                    label: selectedBranchName ?? 'Elegí tu sucursal',
                    onTap: () => context.push('/elegir-sucursal'),
                  ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
                  const SizedBox(height: 22),

                  // ── Tu próximo turno / Reservá ──
                  _TurnoBlock(
                    nextAppointment: nextAppointment,
                    bookable: bookable,
                    acceptsAppointments: auth.acceptsAppointments,
                  ),

                  // ── Points Card ──
                  points.when(
                    data: (data) => PointsCard(
                      totalBalance: (data['total_balance'] ?? 0).toInt(),
                      totalEarned: (data['total_earned'] ?? 0).toInt(),
                      onTap: () => context.push('/points'),
                    ),
                    loading: () => const LiquidSkeleton(height: 150, radius: 26),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 22),

                  // ── Review Banner ──
                  reviews.when(
                    data: (list) {
                      if (list.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          _ReviewBanner(
                            count: list.length,
                            onTap: () => context.push('/reviews'),
                          ),
                          const SizedBox(height: 22),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  // ── Sucursales ──
                  // La fila en vivo sólo tiene sentido donde se atiende por
                  // orden de llegada. En modo `appointments` puro se oculta.
                  if (auth.acceptsWalkIn) ...[
                    LiquidSectionTitle(
                      title: 'Sucursales',
                      subtitle: 'Estado en vivo',
                      onAction: () => context.push('/occupancy'),
                      actionLabel: 'Ver todas',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 128,
                      child: branches.when(
                        data: (list) {
                          if (list.isEmpty) {
                            return Center(
                              child: Text(
                                'Sin sucursales disponibles',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
                            itemBuilder: (context, i) {
                              final b = list[i];
                              return OccupancyMiniCard(
                                branchName: b['branch_name'] ?? 'Sucursal',
                                occupancyLevel: b['occupancy_level'] ?? 'baja',
                                isOpen: (b['is_open'] ?? true) as bool,
                                totalBarbers: (b['total_barbers'] ?? 0).toInt(),
                                onTap: () =>
                                    context.push('/branch/${b['branch_id']}'),
                              ).liquidEnter(index: i, stagger: 70);
                            },
                          );
                        },
                        loading: () => ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 3,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (_, _) =>
                              const LiquidSkeleton(width: 160, height: 128),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 26),
                  ],

                  // ── Cartelera ──
                  billboard.when(
                    data: (items) {
                      if (items.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LiquidSectionTitle(
                            title: 'Cartelera',
                            subtitle: 'Novedades de la barbería',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, i) {
                                final item = items[i];
                                return _BillboardCard(
                                  title: item['title'] ?? '',
                                  subtitle: item['subtitle'] ?? '',
                                  imageUrl: item['image_url'],
                                  onTap: () =>
                                      _handleBillboardTap(context, item),
                                ).liquidEnter(index: i, stagger: 70);
                              },
                            ),
                          ),
                          const SizedBox(height: 26),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  // ── Convenios ──
                  convenios.when(
                    data: (items) {
                      if (items.isEmpty) return const SizedBox.shrink();
                      final preview = items.take(5).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LiquidSectionTitle(
                            title: 'Convenios',
                            subtitle: 'Beneficios exclusivos para vos',
                            onAction: items.length > preview.length
                                ? () => context.push('/convenios')
                                : null,
                            actionLabel: 'Ver todos',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 210,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              itemCount: preview.length +
                                  (items.length > preview.length ? 1 : 0),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, i) {
                                if (i < preview.length) {
                                  final b = preview[i];
                                  return ConvenioHomeCard(
                                    benefit: b,
                                    onTap: () =>
                                        context.push('/convenio/${b['id']}'),
                                  ).liquidEnter(index: i, stagger: 70);
                                }
                                return _ViewAllConveniosCard(
                                  total: items.length,
                                  onTap: () => context.push('/convenios'),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 26),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  // ── Accesos rápidos ──
                  const LiquidSectionTitle(title: 'Accesos rápidos'),
                  const SizedBox(height: 12),
                  _QuickActions(
                    items: [
                      if (bookable)
                        _QuickActionItem(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Reservar',
                          accent: MonacoColors.monacoGreen,
                          onTap: () => context.push('/turnos/reservar'),
                        ),
                      _QuickActionItem(
                        icon: Icons.event_available_rounded,
                        label: 'Mis turnos',
                        onTap: () => context.go('/turnos'),
                      ),
                      _QuickActionItem(
                        icon: Icons.menu_book_rounded,
                        label: 'Catálogo',
                        onTap: () => context.push('/catalog'),
                      ),
                      _QuickActionItem(
                        icon: Icons.card_giftcard_rounded,
                        label: 'Premios',
                        onTap: () => context.go('/rewards'),
                      ),
                      _QuickActionItem(
                        icon: Icons.history_rounded,
                        label: 'Historial',
                        onTap: () => context.push('/visits'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBillboardTap(BuildContext context, Map<String, dynamic> item) {
    final linkType = item['link_type'] as String?;
    final linkValue = (item['link_value'] as String?)?.trim();
    if (linkType == null || linkValue == null || linkValue.isEmpty) return;
    switch (linkType) {
      case 'route':
        if (linkValue.startsWith('/')) context.push(linkValue);
        break;
      case 'url':
        if (linkValue.startsWith('http://') || linkValue.startsWith('https://')) {
          abrirUrlExterna(context, linkValue);
        }
        break;
      case 'branch':
        context.push('/branch/$linkValue');
        break;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final String saludo;
  final String date;

  const _Header({required this.saludo, required this.date});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          saludo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.1,
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideX(begin: -0.05, end: 0, duration: 500.ms),
        const SizedBox(height: 4),
        Text(
          date,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PILL DE SUCURSAL — "Rondeau · Cambiar ›"
// ═══════════════════════════════════════════════════════════════════════════

class _BranchPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BranchPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'Sucursal: $label. Cambiar',
        child: LiquidPill(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          onTap: onTap,
          borderRadius: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cambiar',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TU PRÓXIMO TURNO / RESERVÁ TU TURNO
// ═══════════════════════════════════════════════════════════════════════════

/// Decide qué va arriba de los puntos:
/// - hay un turno próximo (en cualquier sucursal) → tarjeta con countdown;
/// - no hay y la sucursal elegida toma turnos online → CTA "Reservá tu turno";
/// - sucursal walk-in sin turnos → nada (la fila en vivo ya está más abajo).
class _TurnoBlock extends StatelessWidget {
  final AsyncValue<Appointment?> nextAppointment;
  final bool bookable;
  final bool acceptsAppointments;

  const _TurnoBlock({
    required this.nextAppointment,
    required this.bookable,
    required this.acceptsAppointments,
  });

  @override
  Widget build(BuildContext context) {
    final child = nextAppointment.when(
      loading: () => (bookable || acceptsAppointments)
          ? const LiquidSkeleton(height: 132, radius: 26)
          : null,
      error: (_, _) => bookable ? const _BookingCta() : null,
      data: (a) {
        if (a != null) return _NextAppointmentCard(appointment: a);
        if (bookable) return const _BookingCta();
        return null;
      },
    );
    if (child == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: child,
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  final Appointment appointment;
  const _NextAppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final atShop = a.status.isAtShop;
    final accent = atShop ? MonacoColors.info : MonacoColors.monacoGreen;
    final barbero = (a.barberName ?? '').trim();
    final detalle = [
      a.servicesLabel,
      if (barbero.isNotEmpty) 'con $barbero',
    ].join(' · ');

    return Semantics(
      button: true,
      label: 'Tu próximo turno, ${a.horaLabel}, ${a.etiquetaDia()}. Ver detalle',
      child: LiquidGlass(
        onTap: () => context.push('/turnos/${a.id}'),
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        borderRadius: 26,
        tint: accent,
        tintOpacity: 0.12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  atShop ? Icons.storefront_rounded : Icons.event_available_rounded,
                  size: 14,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  atShop ? a.status.label.toUpperCase() : 'TU PRÓXIMO TURNO',
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
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -1.6,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.etiquetaDia(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MonacoColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.15,
                          ),
                        ),
                        if (a.branchName != null)
                          Text(
                            a.branchName!,
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
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                LiquidAvatar(
                  imageUrl: a.barberAvatarUrl,
                  name: barbero,
                  size: 34,
                  tint: accent,
                  fallbackIcon: Icons.content_cut_rounded,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                LiquidPill(
                  onTap: () => context.push('/turnos/${a.id}'),
                  tint: accent,
                  tintOpacity: 0.2,
                  borderRadius: 14,
                  padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0, duration: 400.ms);
  }
}

class _BookingCta extends StatelessWidget {
  const _BookingCta();

  @override
  Widget build(BuildContext context) {
    const accent = MonacoColors.monacoGreen;
    return Semantics(
      button: true,
      label: 'Reservá tu turno',
      child: LiquidGlass(
        onTap: () => context.push('/turnos/reservar'),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        borderRadius: 24,
        tint: accent,
        tintOpacity: 0.13,
        showVignette: false,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.34),
                    accent.withValues(alpha: 0.12),
                  ],
                ),
                border: Border.all(color: accent.withValues(alpha: 0.45), width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 14,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reservá tu turno',
                    style: TextStyle(
                      color: MonacoColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Elegís servicio, día y hora en un minuto. Sin esperar en el local.',
                    style: TextStyle(
                      color: Color(0xA6FFFFFF),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.9),
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 12),
                ],
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0, duration: 400.ms);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REVIEW BANNER — glass pill con tint amber
// ═══════════════════════════════════════════════════════════════════════════

class _ReviewBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ReviewBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const amber = MonacoColors.warning;
    return LiquidGlass(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      tint: amber,
      tintOpacity: 0.12,
      borderRadius: 18,
      showVignette: false,
      scalePressed: 0.97,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  amber.withValues(alpha: 0.28),
                  amber.withValues(alpha: 0.14),
                ],
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: amber.withValues(alpha: 0.42), width: 0.8),
            ),
            child: Center(
              child: Text(
                '$count',
                style: TextStyle(
                  color: amber.withValues(alpha: 0.98),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tenés reseñas pendientes',
              style: TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            'Dejá tu opinión',
            style: TextStyle(
              color: amber.withValues(alpha: 0.98),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 11,
            color: amber.withValues(alpha: 0.98),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.08, end: 0, duration: 400.ms);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BILLBOARD CARD — glass con imagen de fondo y overlay refractado
// ═══════════════════════════════════════════════════════════════════════════

class _BillboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onTap;

  const _BillboardCard({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      onTap: onTap,
      width: 260,
      padding: EdgeInsets.zero,
      borderRadius: 22,
      tintOpacity: 0.06,
      showVignette: false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Positioned.fill(
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: MonacoColors.surfaceVariant,
                  ),
                ),
              ),
            // Tint negro inferior para legibilidad del texto
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// "VER TODOS" — glass con ícono central
// ═══════════════════════════════════════════════════════════════════════════

class _ViewAllConveniosCard extends StatelessWidget {
  final int total;
  final VoidCallback onTap;

  const _ViewAllConveniosCard({required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      onTap: onTap,
      width: 140,
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      tintOpacity: 0.07,
      showVignette: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 0.8,
              ),
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ver todos',
            style: TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$total en total',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACCESOS RÁPIDOS — filas balanceadas de tiles glass (máx. 3 por fila)
// ═══════════════════════════════════════════════════════════════════════════

class _QuickActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
  });
}

/// Reparte los accesos en filas de hasta 3, lo más parejas posible
/// (4 → 2+2, 5 → 3+2, 6 → 3+3): nunca queda un tile solo en una fila.
class _QuickActions extends StatelessWidget {
  final List<_QuickActionItem> items;
  const _QuickActions({required this.items});

  static List<List<T>> _chunk<T>(List<T> list, {int maxPerRow = 3}) {
    if (list.isEmpty) return const [];
    final rows = (list.length / maxPerRow).ceil();
    final base = list.length ~/ rows;
    final extra = list.length % rows;
    final out = <List<T>>[];
    var i = 0;
    for (var r = 0; r < rows; r++) {
      final n = base + (r < extra ? 1 : 0);
      out.add(list.sublist(i, i + n));
      i += n;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _chunk(items);
    var idx = 0;
    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 10),
          Row(
            children: [
              for (var c = 0; c < rows[r].length; c++) ...[
                if (c > 0) const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(item: rows[r][c])
                      .liquidEnter(index: idx++, stagger: 60),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final _QuickActionItem item;
  const _QuickAction({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = item.accent ?? Colors.white;
    final tinted = item.accent != null;
    return Semantics(
      button: true,
      label: item.label,
      child: LiquidGlass(
        onTap: item.onTap,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        borderRadius: 20,
        tint: tinted ? accent : null,
        tintOpacity: tinted ? 0.12 : 0.07,
        showVignette: false,
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: tinted ? 0.32 : 0.18),
                    accent.withValues(alpha: tinted ? 0.12 : 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: accent.withValues(alpha: tinted ? 0.45 : 0.22),
                  width: 0.8,
                ),
                boxShadow: tinted
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: -4,
                        ),
                      ]
                    : null,
              ),
              child: Icon(item.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
