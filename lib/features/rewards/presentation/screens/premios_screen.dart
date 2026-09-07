import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/providers/loyalty_provider.dart';
import 'package:monaco_mobile/features/onboarding/presentation/widgets/muro_login.dart';
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
    ref.invalidate(loyaltyProvider);
    ref.invalidate(clientWalletProvider);
    await ref
        .read(catalogoPremiosProvider.future)
        .then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    // Sin cuenta la pantalla es una **vidriera**: se explica el programa y se
    // invita a crearla. No se dibuja la grilla vacía con "Todavía no hay
    // premios", que sería mentira: el catálogo existe, es que no lo podemos
    // pedir sin sesión (`get_loyalty_catalog` resuelve por `auth.uid()`).
    if (ref.watch(authProvider.select((a) => a.isGuest))) {
      return const _VidrieraInvitado();
    }

    final premios = ref.watch(premiosProvider);
    final saldo = ref.watch(saldoPuntosProvider).valueOrNull ?? 0;
    final loyalty = ref.watch(loyaltyProvider).valueOrNull;
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
        (_categoria != null && categorias.contains(_categoria))
        ? _categoria
        : null;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Canjeá en el local mostrando el código.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Sin programa no hay categoría que mostrar: la línea
                        // no existe, no dice "sin categoría".
                        if (loyalty != null && loyalty.tieneCategoria) ...[
                          const SizedBox(height: 8),
                          _LineaCategoria(
                            tier: loyalty.tier!,
                            onTap: () => context.push('/categoria'),
                          ),
                        ],
                      ],
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
                      title:
                          'Nada en ${categoriaActiva?.label ?? 'esta categoría'}',
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
                          final i = visibles.indexWhere(
                            (p) => p.id == key.value,
                          );
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
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
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
// CATEGORÍA — "Cliente Oro · sumás al 110 %"
// ═══════════════════════════════════════════════════════════════════════════

class _LineaCategoria extends StatelessWidget {
  final LoyaltyTier tier;
  final VoidCallback onTap;
  const _LineaCategoria({required this.tier, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = 'Cliente ${tier.name} · sumás al ${tier.multiplierPct} %';
    return Semantics(
      button: true,
      label: '$label. Ver mi categoría',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                size: 15,
                color: tier.acentoSobreOscuro,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),
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

// ═══════════════════════════════════════════════════════════════════════════
// VIDRIERA — Premios sin cuenta
// ═══════════════════════════════════════════════════════════════════════════

/// Lo que ve un invitado en el tab Premios.
///
/// Muestra **qué** se puede conseguir (las tres categorías reales del catálogo)
/// sin prometer precios: el catálogo con los puntos de cada premio sale de
/// `get_loyalty_catalog()`, que resuelve por `auth.uid()` y no tiene grant para
/// `anon`. Inventar precios acá sería mostrarle al cliente un número que
/// después no coincide.
class _VidrieraInvitado extends ConsumerWidget {
  const _VidrieraInvitado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiquidAppBarScaffold(
      title: 'Premios',
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
        children: [
          Text(
            'Cada corte suma puntos y te sube de categoría. Los puntos se '
            'canjean en el local mostrando el código.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          for (final c in PremioCategoria.values) ...[
            _CategoriaVidriera(categoria: c).liquidEnter(index: c.index),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 10),
          LiquidGlass(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            borderRadius: 22,
            tintOpacity: 0.09,
            showVignette: false,
            pressable: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ver el catálogo completo',
                  style: TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Los premios, cuántos puntos cuesta cada uno y cuánto te '
                  'falta se ven con tu cuenta.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: LiquidTapEffect(
                    onTap: () =>
                        pedirCuenta(context, ref, AccionConCuenta.canjear),
                    borderRadius: BorderRadius.circular(16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // Blanco sólido: es el CTA principal de la pantalla, y
                        // en este lenguaje lo opaco es lo que se toca. El verde
                        // queda para lo que significa algo del negocio.
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'Crear mi cuenta',
                          style: TextStyle(
                            color: MonacoColors.background,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ).liquidEnter(index: 4),
        ],
      ),
    );
  }
}

class _CategoriaVidriera extends StatelessWidget {
  final PremioCategoria categoria;
  const _CategoriaVidriera({required this.categoria});

  static const _detalle = {
    PremioCategoria.cortes:
        'Descuentos y servicios gratis en cualquier sucursal.',
    PremioCategoria.merch: 'Gorras, remeras y productos de la barbería.',
    PremioCategoria.marcas:
        'Beneficios en comercios amigos, sin gastar puntos.',
  };

  @override
  Widget build(BuildContext context) {
    final acento = categoria.acento;
    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      borderRadius: 20,
      tintOpacity: 0.06,
      showVignette: false,
      pressable: false,
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
                  acento.withValues(alpha: 0.3),
                  acento.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(
                color: acento.withValues(alpha: 0.42),
                width: 0.8,
              ),
            ),
            child: Icon(categoria.icono, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoria.label,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _detalle[categoria]!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 12.5,
                    height: 1.35,
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
