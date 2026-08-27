import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/features/appointments/data/fechas.dart';
import 'package:monaco_mobile/features/appointments/presentation/widgets/turno_links.dart';
import 'package:monaco_mobile/features/appointments/providers/appointments_provider.dart';
import 'package:monaco_mobile/features/appointments/providers/booking_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/home/presentation/widgets/home_header.dart';
import 'package:monaco_mobile/features/home/presentation/widgets/occupancy_mini_card.dart';
import 'package:monaco_mobile/features/home/presentation/widgets/turno_tiles.dart';
import 'package:monaco_mobile/features/home/presentation/widgets/wallet_points_card.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';
import 'package:monaco_mobile/features/points/providers/points_provider.dart';
import 'package:monaco_mobile/features/reviews/providers/reviews_provider.dart';
import 'package:monaco_mobile/features/rewards/data/premio_item.dart';
import 'package:monaco_mobile/features/rewards/presentation/widgets/canje.dart';
import 'package:monaco_mobile/features/rewards/presentation/widgets/premio_card.dart';
import 'package:monaco_mobile/features/rewards/providers/premios_provider.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

final _pts = NumberFormat.decimalPattern('es_AR');

/// Ancho de la tarjeta del carrusel "Canjeá tus puntos". Fijo (no depende del
/// teléfono) para que se vea siempre media tarjeta al costado: eso es lo que
/// dice "esto se desliza".
const _anchoTarjetaPremio = 162.0;

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

/// **Inicio — una billetera.**
///
/// El orden no es decorativo, es una jerarquía: qué tenés (puntos) → qué te
/// pasa hoy (tu turno) → dónde ir ahora (espera en vivo) → qué podés conseguir
/// (premios) → qué hay de nuevo (cartelera).
///
/// La app dejó de tener sucursal: el saludo no la nombra, no hay pill para
/// cambiarla y la fila en vivo muestra **todas**. La sucursal se elige recién
/// al reservar un turno, que es el único momento en que la respuesta cambia
/// algo.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final saldo = ref.watch(saldoPuntosProvider);
    final reviews = ref.watch(pendingReviewsProvider);
    final branches = ref.watch(branchSignalsProvider);
    final billboard = ref.watch(billboardProvider);
    final premios = ref.watch(premiosProvider);
    final proximoTurno = ref.watch(nextAppointmentProvider);
    final reservable = ref.watch(hayTurnosOnlineProvider);

    final firstName = auth.firstName;
    final saludo = firstName.isEmpty ? 'Hola' : 'Hola, $firstName';

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
              ref.invalidate(catalogoPremiosProvider);
              ref.invalidate(clientWalletProvider);
              ref.invalidate(upcomingAppointmentsProvider);
              ref.invalidate(mobileBranchesProvider);
              await Future.wait([
                ref.read(globalPointsProvider.future),
                ref.read(upcomingAppointmentsProvider.future),
              ]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HomeHeader(),
                  const SizedBox(height: 18),

                  _Saludo(saludo: saludo, fecha: Fechas.fechaLarga(DateTime.now())),
                  const SizedBox(height: 18),

                  // ── La tarjeta ──
                  saldo.when(
                    data: (valor) => _TarjetaPuntos(saldo: valor),
                    loading: () => const LiquidSkeleton(height: 168, radius: 26),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),

                  // ── Turnos ──
                  TurnoTiles(
                    proximo: proximoTurno.valueOrNull,
                    cargando: proximoTurno.isLoading && !proximoTurno.hasValue,
                    reservable: reservable,
                  ),
                  const SizedBox(height: 24),

                  // ── Reseñas pendientes ──
                  reviews.when(
                    data: (list) => list.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _ReviewBanner(
                              count: list.length,
                              onTap: () => context.push('/reviews'),
                            ),
                          ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  // ── Espera ahora ──
                  LiquidSectionTitle(
                    title: 'Espera ahora',
                    subtitle: 'Estado en vivo de las sucursales',
                    onAction: () => context.go('/occupancy'),
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
                              onTap: () => context.push('/branch/${b['branch_id']}'),
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

                  // ── Canjeá tus puntos ──
                  _CarruselPremios(premios: premios, saldo: saldo.valueOrNull ?? 0),

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
                              separatorBuilder: (_, _) => const SizedBox(width: 12),
                              itemBuilder: (context, i) {
                                final item = items[i];
                                return _BillboardCard(
                                  title: item['title'] ?? '',
                                  subtitle: item['subtitle'] ?? '',
                                  imageUrl: item['image_url'],
                                  onTap: () => _abrirCartelera(context, item),
                                ).liquidEnter(index: i, stagger: 70);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _abrirCartelera(BuildContext context, Map<String, dynamic> item) {
    final linkType = item['link_type'] as String?;
    final linkValue = (item['link_value'] as String?)?.trim();
    if (linkType == null || linkValue == null || linkValue.isEmpty) return;
    switch (linkType) {
      case 'route':
        if (linkValue.startsWith('/')) context.push(linkValue);
      case 'url':
        if (linkValue.startsWith('http://') || linkValue.startsWith('https://')) {
          abrirUrlExterna(context, linkValue);
        }
      case 'branch':
        context.push('/branch/$linkValue');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SALUDO
// ═══════════════════════════════════════════════════════════════════════════

class _Saludo extends StatelessWidget {
  final String saludo;
  final String fecha;

  const _Saludo({required this.saludo, required this.fecha});

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
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideX(begin: -0.05, end: 0, duration: 500.ms),
        const SizedBox(height: 3),
        Text(
          fecha,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ).animate().fadeIn(delay: 180.ms, duration: 400.ms),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TARJETA DE PUNTOS — el pie sale del catálogo REAL
// ═══════════════════════════════════════════════════════════════════════════

class _TarjetaPuntos extends ConsumerWidget {
  final int saldo;
  const _TarjetaPuntos({required this.saldo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proximo = ref.watch(proximoPremioProvider);
    final canjeables = ref.watch(premiosCanjeablesProvider);

    // Tres estados, en orden de utilidad para el cliente:
    //   1. le falta poco para algo concreto → decile qué y cuánto;
    //   2. ya le alcanza para algo → decile que vaya a buscarlo;
    //   3. no hay catálogo cargado → no inventes una meta que no existe.
    final String pie;
    final double? progreso;
    if (proximo != null) {
      pie = 'A ${_pts.format(proximo.faltan(saldo))} pts de ${proximo.nombre}';
      progreso = proximo.progreso(saldo);
    } else if (canjeables > 0) {
      pie = canjeables == 1
          ? 'Ya podés canjear un premio'
          : 'Ya podés canjear $canjeables premios';
      progreso = 1;
    } else {
      pie = 'Sumás puntos en cada visita';
      progreso = null;
    }

    return WalletPointsCard(
      saldo: saldo,
      progreso: progreso,
      pie: pie,
      onTap: () => context.push('/points'),
      onPremios: () => context.go('/rewards'),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARRUSEL "CANJEÁ TUS PUNTOS"
// ═══════════════════════════════════════════════════════════════════════════

class _CarruselPremios extends ConsumerWidget {
  final AsyncValue<List<PremioItem>> premios;
  final int saldo;

  const _CarruselPremios({required this.premios, required this.saldo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = premios.valueOrNull;

    // Sin catálogo no hay sección: un carrusel vacío con título es peor que
    // nada. Mientras carga tampoco reservamos espacio — la pantalla ya tiene
    // contenido arriba y el salto se percibe menos que un hueco gris.
    if (items == null || items.isEmpty) return const SizedBox.shrink();

    // La sección se llama "Canjeá tus puntos": los premios de la barbería van
    // primero, siempre. En la pantalla de Premios manda "lo que podés usar
    // ahora" (y ahí los convenios gratis encabezan con razón), pero acá eso
    // hacía que un cliente con 0 puntos abriera con tres tarjetas GRATIS bajo un
    // título que habla de puntos.
    final preview = [
      ...items.where((p) => p.origen == PremioOrigen.catalogo),
      ...items.where((p) => p.origen == PremioOrigen.convenio),
    ].take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LiquidSectionTitle(
          title: 'Canjeá tus puntos',
          subtitle: 'Premios y beneficios de Monaco',
          onAction: () => context.go('/rewards'),
          actionLabel: 'Ver todos',
        ),
        const SizedBox(height: 12),
        SizedBox(
          // El alto lo dice la tarjeta (lámina + 2 líneas + barra de canje), no
          // un número a ojo: con 230 desbordaba 15 px.
          height: PremioCard.altoPara(_anchoTarjetaPremio),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: preview.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final p = preview[i];
              return PremioCard(
                premio: p,
                saldo: saldo,
                width: _anchoTarjetaPremio,
                onTap: () => abrirPremio(context, ref, p, saldo),
              ).liquidEnter(index: i, stagger: 70);
            },
          ),
        ),
        const SizedBox(height: 26),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REVIEW BANNER
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
// CARTELERA
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
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: MonacoColors.surfaceVariant),
                ),
              ),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
