import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/points/providers/points_provider.dart';
import 'package:monaco_mobile/features/rewards/data/premio_item.dart';
import 'package:monaco_mobile/features/rewards/presentation/widgets/canje.dart';
import 'package:monaco_mobile/features/rewards/presentation/widgets/premio_card.dart';
import 'package:monaco_mobile/features/rewards/presentation/widgets/pastilla_solida.dart';
import 'package:monaco_mobile/features/rewards/presentation/widgets/premio_listo_card.dart';
import 'package:monaco_mobile/features/rewards/providers/premios_provider.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

final _pts = NumberFormat.decimalPattern('es_AR');

/// **Premios** — tab del dock. Es la tienda: todo lo que el cliente puede
/// obtener, en una grilla de dos columnas con chips de categoría.
///
/// Arriba, si tiene premios ya canjeados, va la tira "Listos para usar" con el
/// QR: primero lo que ya es suyo, después lo que puede conseguir. Es el orden de
/// una billetera, y evita que alguien canjee dos veces porque no encontró el
/// premio que ya tenía.
///
/// Unifica lo que antes eran dos pantallas —`/rewards` (billetera) y `/catalog`
/// (canjear)— más los convenios, que entran como categoría "Marcas" con la
/// pastilla GRATIS porque no cuestan puntos.
class PremiosScreen extends ConsumerStatefulWidget {
  const PremiosScreen({super.key});

  @override
  ConsumerState<PremiosScreen> createState() => _PremiosScreenState();
}

class _PremiosScreenState extends ConsumerState<PremiosScreen> {
  /// `null` = "Todo".
  PremioCategoria? _categoria;

  Future<void> _refresh() async {
    ref.invalidate(catalogoPremiosProvider);
    ref.invalidate(conveniosProvider);
    ref.invalidate(globalPointsProvider);
    ref.invalidate(clientWalletProvider);
    await ref
        .read(catalogoPremiosProvider.future)
        .then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final premios = ref.watch(premiosProvider);
    final saldo = ref.watch(saldoPuntosProvider).valueOrNull ?? 0;
    final categorias = ref.watch(categoriasConPremiosProvider);
    final listos = ref.watch(premiosListosProvider).valueOrNull ?? const [];
    // Historial: si el cliente usó premios y no le queda ninguno vivo, la tira
    // desaparece y con ella el único enlace a la billetera. En prod eso es el
    // 100 % de los clientes con historial (272 vencidos + 8 usados, cero
    // disponibles), así que la solapa "Usados" quedaba inalcanzable.
    final tieneHistorial =
        (ref.watch(clientWalletProvider).valueOrNull ?? const []).isNotEmpty;

    // Un chip que se queda seleccionado después de que su categoría se vació
    // dejaría la grilla en blanco sin explicación.
    final categoriaActiva =
        (_categoria != null && categorias.contains(_categoria)) ? _categoria : null;

    return LiquidAppBarScaffold(
      title: 'Premios',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: _SaldoPill(saldo: saldo, onTap: () => context.push('/points')),
        ),
      ],
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: MonacoColors.surface,
        onRefresh: _refresh,
        child: premios.when(
          loading: () => const _SkeletonPremios(),
          error: (e, _) => LiquidErrorState(error: e, onRetry: _refresh),
          data: (items) {
            final visibles = categoriaActiva == null
                ? items
                : items.where((p) => p.categoria == categoriaActiva).toList();

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Text(
                      'Canjeá en el local mostrando el código.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                if (listos.isNotEmpty)
                  SliverToBoxAdapter(child: _TiraListos(rewards: listos))
                else if (tieneHistorial)
                  const SliverToBoxAdapter(child: _LinkBilletera()),

                if (categorias.length > 1)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ChipsHeader(
                      categorias: categorias,
                      seleccionada: categoriaActiva,
                      onSelect: (c) => setState(() => _categoria = c),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                if (items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: LiquidEmptyState(
                      icon: Icons.card_giftcard_outlined,
                      title: 'Todavía no hay premios',
                      message:
                          'Cuando la barbería cargue premios canjeables o convenios con comercios, te van a aparecer acá. Mientras tanto, cada visita te suma puntos.',
                      scrollable: false,
                    ),
                  )
                else if (visibles.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: LiquidEmptyState(
                      icon: categoriaActiva?.icono ?? Icons.search_off_rounded,
                      title: 'Nada en ${categoriaActiva?.label ?? 'esta categoría'}',
                      message: 'Probá con otra categoría o mirá todo junto.',
                      ctaLabel: 'Ver todo',
                      onCta: () => setState(() => _categoria = null),
                      scrollable: false,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        // El alto lo decide la tarjeta, no la pantalla: un
                        // `childAspectRatio` a ojo era lo que la desbordaba.
                        childAspectRatio: PremioCard.aspectoGrilla(
                          (MediaQuery.sizeOf(context).width - 40 - 14) / 2,
                        ),
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final p = visibles[i];
                          // La clave va en el widget MÁS EXTERNO: `liquidEnter`
                          // envuelve la tarjeta, así que una key sobre
                          // `PremioCard` quedaría adentro del wrapper y el
                          // sliver nunca la vería.
                          return KeyedSubtree(
                            key: ValueKey(p.id),
                            child: PremioCard(
                              premio: p,
                              saldo: saldo,
                              onTap: () => abrirPremio(context, ref, p, saldo),
                            ).liquidEnter(index: i, stagger: 50),
                          );
                        },
                        childCount: visibles.length,
                        // Filtrar por categoría cambia el orden: sin esto,
                        // Flutter reusa el elemento de la posición y las
                        // tarjetas muestran los datos de otro premio por un
                        // frame (y la animación de entrada se re-dispara).
                        findChildIndexCallback: (key) {
                          if (key is! ValueKey<String>) return null;
                          final i = visibles.indexWhere((p) => p.id == key.value);
                          return i < 0 ? null : i;
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TIRA "LISTOS PARA USAR"
// ═══════════════════════════════════════════════════════════════════════════

class _TiraListos extends StatelessWidget {
  final List<Map<String, dynamic>> rewards;
  const _TiraListos({required this.rewards});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LiquidSectionTitle(
            title: 'Listos para usar',
            subtitle: rewards.length == 1
                ? 'Mostralo en el local'
                : '${rewards.length} premios esperándote',
            onAction: () => context.push('/mis-premios'),
            actionLabel: 'Ver todos',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: PremioListoCard.alto,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: rewards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final r = rewards[i];
              return PremioListoCard(
                reward: r,
                onTap: () =>
                    context.push('/reward-qr/${r['client_reward_id']}'),
              ).liquidEnter(index: i, stagger: 70);
            },
          ),
        ),
      ],
    );
  }
}

/// Enlace a la billetera cuando no hay ningún premio vivo pero sí historial.
/// Sin esto, "Mis premios → Usados" no tiene entrada desde esta pantalla.
class _LinkBilletera extends StatelessWidget {
  const _LinkBilletera();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: LiquidPill(
          onTap: () => context.push('/mis-premios'),
          padding: const EdgeInsets.fromLTRB(13, 8, 11, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_rounded,
                size: 15,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 7),
              Text(
                'Premios que ya usaste',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHIPS DE CATEGORÍA — pegados arriba mientras se scrollea la grilla
// ═══════════════════════════════════════════════════════════════════════════

class _ChipsHeader extends SliverPersistentHeaderDelegate {
  final List<PremioCategoria> categorias;
  final PremioCategoria? seleccionada;
  final ValueChanged<PremioCategoria?> onSelect;

  const _ChipsHeader({
    required this.categorias,
    required this.seleccionada,
    required this.onSelect,
  });

  static const double _alto = 74;

  @override
  double get minExtent => _alto;
  @override
  double get maxExtent => _alto;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DecoratedBox(
      // Opaco a propósito: la grilla pasa por detrás y un fondo translúcido
      // deja ver las tarjetas cruzando los chips.
      decoration: const BoxDecoration(color: MonacoColors.background),
      child: SizedBox(
        height: _alto,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          children: [
            _Chip(
              label: 'Todo',
              seleccionado: seleccionada == null,
              onTap: () => onSelect(null),
            ),
            // Sin íconos: con los cuatro chips + ícono, "Marcas" se salía de la
            // pantalla en un iPhone de 390 pt y había que scrollear para ver que
            // existía. El texto solo entra completo.
            for (final c in categorias) ...[
              const SizedBox(width: 8),
              _Chip(
                label: c.label,
                seleccionado: seleccionada == c,
                onTap: () => onSelect(c),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ChipsHeader old) =>
      old.seleccionada != seleccionada || !_mismasCategorias(old.categorias);

  bool _mismasCategorias(List<PremioCategoria> otras) {
    if (otras.length != categorias.length) return false;
    for (var i = 0; i < otras.length; i++) {
      if (otras[i] != categorias[i]) return false;
    }
    return true;
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final contenido = Text(
      label,
      style: TextStyle(
        color: seleccionado
            ? MonacoColors.primaryForeground
            : Colors.white.withValues(alpha: 0.75),
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.1,
      ),
    );

    return Center(
      child: Semantics(
        button: true,
        selected: seleccionado,
        child: seleccionado
            // Blanco SÓLIDO. `LiquidPill` nunca llega a opaco (su gradiente
            // termina en tint × 0.55, o sea 50% de blanco abajo a la derecha) y
            // el texto negro sobre eso queda ilegible.
            ? PastillaSolida(onTap: onTap, child: contenido)
            : LiquidPill(
                onTap: onTap,
                tintOpacity: 0.08,
                padding: const EdgeInsets.fromLTRB(15, 9, 15, 9),
                child: contenido,
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SALDO
// ═══════════════════════════════════════════════════════════════════════════

class _SaldoPill extends StatelessWidget {
  final int saldo;
  final VoidCallback onTap;
  const _SaldoPill({required this.saldo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tenés $saldo puntos. Ver detalle',
      child: PastillaSolida(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(13, 7, 13, 7),
        child: Text(
          '${_pts.format(saldo)} pts',
          style: const TextStyle(
            color: MonacoColors.primaryForeground,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.1,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SKELETON
// ═══════════════════════════════════════════════════════════════════════════

class _SkeletonPremios extends StatelessWidget {
  const _SkeletonPremios();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: LiquidSkeleton.line(width: 230, height: 14),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: const [
                LiquidSkeleton(width: 78, height: 36, radius: 999),
                SizedBox(width: 8),
                LiquidSkeleton(width: 96, height: 36, radius: 999),
                SizedBox(width: 8),
                LiquidSkeleton(width: 90, height: 36, radius: 999),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              // Mismo aspecto que la grilla real: si difieren, al cargar los
              // datos las tarjetas cambian de alto y la pantalla "salta".
              childAspectRatio: PremioCard.aspectoGrilla(
                (MediaQuery.sizeOf(context).width - 40 - 14) / 2,
              ),
            ),
            delegate: SliverChildBuilderDelegate(
              (_, _) => const LiquidSkeleton(radius: 22),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }
}
