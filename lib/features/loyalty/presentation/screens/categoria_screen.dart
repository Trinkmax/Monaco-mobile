import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/presentation/widgets/monaco_card.dart';
import 'package:monaco_mobile/features/loyalty/providers/loyalty_provider.dart';

/// **Mi categoría** (`/categoria`): la tarjeta del cliente arriba, el carrusel
/// con las cuatro categorías (rango, beneficios) y "Cómo funciona" con los
/// valores REALES del programa. Todo sale de `get_client_loyalty`: no hay un
/// solo umbral ni multiplicador escrito acá.
class CategoriaScreen extends ConsumerWidget {
  const CategoriaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loyalty = ref.watch(loyaltyProvider);

    return LiquidAppBarScaffold(
      title: 'Mi categoría',
      showBackButton: true,
      body: loyalty.when(
        loading: () => const _Cargando(),
        error: (e, _) => LiquidErrorState(
          error: e,
          onRetry: () => invalidarLoyalty(ref),
        ),
        data: (summary) => RefreshIndicator(
          color: Colors.white,
          backgroundColor: MonacoColors.surface,
          onRefresh: () async {
            invalidarLoyalty(ref);
            await ref.read(loyaltyProvider.future).then((_) {}, onError: (_) {});
          },
          child: _Cuerpo(summary: summary),
        ),
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      children: const [
        AspectRatio(
          aspectRatio: MonacoCard.proporcion,
          child: LiquidSkeleton(radius: MonacoCard.radio),
        ),
        SizedBox(height: 22),
        LiquidSkeleton.line(width: 140, height: 18),
        SizedBox(height: 12),
        LiquidSkeleton(height: 260),
        SizedBox(height: 22),
        LiquidSkeleton(height: 180),
      ],
    );
  }
}

class _Cuerpo extends StatelessWidget {
  final LoyaltySummary summary;
  const _Cuerpo({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final tiers = s.tiers;
    final grace = s.grace;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      children: [
        MonacoCard(
          summary: s,
          saldo: s.points.balance,
          onTap: () => context.push('/points'),
        ).liquidEnter(index: 0),
        const SizedBox(height: 14),

        if (!s.programEnabled) ...[
          const _ProgramaApagado().liquidEnter(index: 1),
        ] else ...[
          if (grace != null) ...[
            _BloqueGracia(summary: s, grace: grace).liquidEnter(index: 1),
            const SizedBox(height: 14),
          ],
          if (tiers.isNotEmpty) ...[
            const SizedBox(height: 6),
            const LiquidSectionTitle(
              title: 'Categorías',
              subtitle: 'Se calculan con tus visitas recientes',
            ).liquidEnter(index: 2),
            const SizedBox(height: 12),
            _CarruselCategorias(summary: s).liquidEnter(index: 3),
            const SizedBox(height: 22),
          ],
          const LiquidSectionTitle(title: 'Cómo funciona').liquidEnter(index: 4),
          const SizedBox(height: 12),
          _ComoFunciona(summary: s).liquidEnter(index: 5),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROGRAMA APAGADO
// ═══════════════════════════════════════════════════════════════════════════

class _ProgramaApagado extends StatelessWidget {
  const _ProgramaApagado();

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      pressable: false,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24), width: 0.8),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Las categorías llegan pronto',
                  style: TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'El programa de categorías todavía no está activo. Cuando arranque vas a ver acá tu nivel, tus beneficios y cuánto te falta para el siguiente.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    height: 1.45,
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

// ═══════════════════════════════════════════════════════════════════════════
// GRACIA
// ═══════════════════════════════════════════════════════════════════════════

class _BloqueGracia extends StatelessWidget {
  final LoyaltySummary summary;
  final LoyaltyGrace grace;
  const _BloqueGracia({required this.summary, required this.grace});

  @override
  Widget build(BuildContext context) {
    const amber = MonacoColors.warning;
    final tier = summary.tier;
    final d = grace.daysLeft;
    final cuando = d <= 0
        ? 'hoy'
        : d == 1
            ? 'mañana'
            : 'en $d días';
    final despues = grace.tierAfterName;
    return LiquidGlass(
      pressable: false,
      tint: amber,
      tintOpacity: 0.12,
      borderRadius: 20,
      showVignette: false,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tu nivel ${tier?.name ?? ''} vence $cuando',
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            despues == null
                ? 'Con una visita antes de esa fecha mantenés tu categoría.'
                : 'Con una visita antes de esa fecha mantenés tu categoría. Si no, pasás a $despues.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          LiquidButton(
            tint: MonacoColors.seleccion,
            onPressed: () => context.go('/turnos'),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_available_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Reservar turno',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
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

// ═══════════════════════════════════════════════════════════════════════════
// CARRUSEL DE CATEGORÍAS
// ═══════════════════════════════════════════════════════════════════════════

class _CarruselCategorias extends StatefulWidget {
  final LoyaltySummary summary;
  const _CarruselCategorias({required this.summary});

  @override
  State<_CarruselCategorias> createState() => _CarruselCategoriasState();
}

class _CarruselCategoriasState extends State<_CarruselCategorias> {
  static const _fraccion = 0.82;
  late final PageController _ctrl;

  int get _indiceActual {
    final code = widget.summary.tier?.code;
    final i = widget.summary.tiers.indexWhere((t) => t.code == code);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: _fraccion, initialPage: _indiceActual);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final tiers = s.tiers;
    final maxBeneficios = tiers.fold<int>(0, (m, t) => t.benefits.length > m ? t.benefits.length : m);

    return LayoutBuilder(
      builder: (context, c) {
        final anchoPagina = c.maxWidth * _fraccion;
        final anchoTarjeta = anchoPagina - 12;
        final altoTarjeta = MonacoCard.alturaPara(anchoTarjeta);
        // Alto fijo del PageView: tarjeta + etiqueta + beneficios (los que
        // tenga la categoría con más). Sin esto el PageView no tiene alto.
        final alto = altoTarjeta + 14 + 20 + 8 + maxBeneficios * 26.0 + 8;

        return SizedBox(
          height: alto,
          child: PageView.builder(
            controller: _ctrl,
            clipBehavior: Clip.none,
            itemCount: tiers.length,
            itemBuilder: (context, i) {
              final t = tiers[i];
              final esActual = t.code == s.tier?.code;
              return AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) {
                  double page = _indiceActual.toDouble();
                  if (_ctrl.hasClients && _ctrl.position.hasContentDimensions) {
                    page = _ctrl.page ?? page;
                  }
                  final dist = (page - i).abs().clamp(0.0, 1.0);
                  final escala = 1 - dist * 0.08;
                  final opacidad = 1 - dist * 0.35;
                  return Transform.scale(
                    scale: escala,
                    alignment: Alignment.topCenter,
                    child: Opacity(opacity: opacidad, child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _PaginaCategoria(
                    summary: s,
                    tier: t,
                    esActual: esActual,
                    anchoTarjeta: anchoTarjeta,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PaginaCategoria extends StatelessWidget {
  final LoyaltySummary summary;
  final LoyaltyTier tier;
  final bool esActual;
  final double anchoTarjeta;

  const _PaginaCategoria({
    required this.summary,
    required this.tier,
    required this.esActual,
    required this.anchoTarjeta,
  });

  @override
  Widget build(BuildContext context) {
    final semanas = summary.program.windowWeeks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: anchoTarjeta,
          child: MonacoCard(
            summary: summary,
            saldo: summary.points.balance,
            tier: tier,
            compact: true,
            animarContador: false,
            conDorso: false,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 20,
          child: Row(
            children: [
              if (esActual)
                _Etiqueta(texto: 'TU CATEGORÍA', color: Colors.white)
              else
                _Etiqueta(
                  texto: '${tier.rangoLabel.toUpperCase()} EN $semanas SEMANAS',
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              const Spacer(),
              Text(
                '${tier.multiplierPct} %',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final b in tier.benefits)
          SizedBox(
            height: 26,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: tier.colorSecondary.computeLuminance() > 0.08
                        ? tier.colorSecondary
                        : Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  const _Etiqueta({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CÓMO FUNCIONA — con los valores del server
// ═══════════════════════════════════════════════════════════════════════════

class _ComoFunciona extends StatelessWidget {
  final LoyaltySummary summary;
  const _ComoFunciona({required this.summary});

  @override
  Widget build(BuildContext context) {
    final p = summary.program;
    final tier = summary.tier;
    final mult = tier?.multiplierPct;
    final filas = <(IconData, String)>[
      (
        Icons.content_cut_rounded,
        mult == null
            ? 'Cada visita suma ${p.basePoints} pts × el multiplicador de tu categoría.'
            : 'Cada visita suma ${p.basePoints} pts × tu multiplicador ($mult % en ${tier!.name}).',
      ),
      (
        Icons.hourglass_bottom_rounded,
        'Los puntos vencen a los ${p.expiryDays} días de ganarlos.',
      ),
      (
        Icons.calendar_month_rounded,
        'Tu categoría se calcula con las visitas de las últimas ${p.windowWeeks} semanas.',
      ),
      (Icons.shield_rounded, p.textoGracia),
      if (p.welcomeBonusPoints > 0)
        (
          Icons.celebration_rounded,
          'Bono de bienvenida: ${p.welcomeBonusPoints} pts al entrar al programa.',
        ),
    ];

    return LiquidGlass(
      pressable: false,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          for (var i = 0; i < filas.length; i++) ...[
            if (i > 0)
              Container(
                height: 0.5,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
                    ),
                    child: Icon(filas[i].$1, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        filas[i].$2,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
