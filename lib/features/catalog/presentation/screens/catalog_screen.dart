import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/features/catalog/providers/catalog_provider.dart';
import 'package:monaco_mobile/features/points/providers/points_provider.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

final _pts = NumberFormat.decimalPattern('es_AR');

// ---------------------------------------------------------------------------
// Saldo global (sólo el número). Se mantiene como provider propio del catálogo
// porque se invalida al canjear junto con el de la pantalla de Puntos.
// ---------------------------------------------------------------------------
final clientGlobalPointsProvider = FutureProvider<int>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.rpc('get_client_global_points');
  // La RPC devuelve TABLE → List con una fila con total_balance
  if (res is List && res.isNotEmpty) {
    final row = res.first;
    return (row['total_balance'] as num?)?.toInt() ?? 0;
  }
  if (res is Map) {
    return (res['total_balance'] as num?)?.toInt() ?? 0;
  }
  return 0;
});

// ---------------------------------------------------------------------------
// Pantalla
// ---------------------------------------------------------------------------
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(catalogProvider);
    ref.invalidate(clientGlobalPointsProvider);
    await ref.read(catalogProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCatalog = ref.watch(catalogProvider);
    final asyncPoints = ref.watch(clientGlobalPointsProvider);

    return LiquidAppBarScaffold(
      title: 'Canjear puntos',
      showBackButton: true,
      body: asyncCatalog.when(
        loading: () => const _SkeletonGrid(),
        error: (e, _) => LiquidErrorState(
          error: e,
          onRetry: () => _refresh(ref),
        ),
        data: (items) {
          final userPoints = asyncPoints.valueOrNull ?? 0;
          return RefreshIndicator(
            color: Colors.white,
            backgroundColor: MonacoColors.surface,
            onRefresh: () => _refresh(ref),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _BalanceHeader(
                      points: asyncPoints,
                      onRetry: () => ref.invalidate(clientGlobalPointsProvider),
                    ).liquidEnter(index: 0),
                  ),
                ),
                if (items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: LiquidEmptyState(
                      icon: Icons.card_giftcard_outlined,
                      title: 'No hay premios para canjear',
                      message:
                          'Cuando la barbería cargue premios canjeables por puntos van a aparecer acá.',
                      scrollable: false,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 48),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.70,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = items[index];
                          return _CatalogCard(
                            item: item,
                            userPoints: userPoints,
                            onTap: () => _onTapItem(context, ref, item, userPoints),
                          ).liquidEnter(index: index + 1, stagger: 50);
                        },
                        childCount: items.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- Canje ----

  Future<void> _onTapItem(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
    int userPoints,
  ) async {
    final cost = (item['points_cost'] as num?)?.toInt() ?? 0;
    final name = item['name'] as String? ?? 'Premio';
    final stock = (item['stock'] as num?)?.toInt();
    final outOfStock = stock != null && stock <= 0;

    HapticFeedback.selectionClick();

    if (outOfStock) {
      showLiquidToast(
        context,
        'Este premio está agotado por ahora.',
        tone: LiquidToastTone.info,
      );
      return;
    }

    if (userPoints < cost) {
      final missing = cost - userPoints;
      await showLiquidDialog<void>(
        context,
        title: name,
        icon: Icons.lock_outline_rounded,
        message:
            'Te faltan ${_pts.format(missing)} pts para canjearlo. Cada visita suma puntos, así que ya casi.',
        content: _RedeemPreview(item: item, cost: cost, userPoints: userPoints),
        actions: const [
          LiquidDialogAction<void>(label: 'Entendido'),
        ],
      );
      return;
    }

    final confirmed = await showLiquidDialog<bool>(
      context,
      title: 'Confirmar canje',
      icon: Icons.redeem_rounded,
      iconColor: MonacoColors.monacoGreen,
      message:
          'Vas a canjear ${_pts.format(cost)} pts por este premio. Después lo mostrás con un QR al barbero.',
      content: _RedeemPreview(item: item, cost: cost, userPoints: userPoints),
      actions: const [
        LiquidDialogAction<bool>(label: 'Cancelar', value: false),
        LiquidDialogAction<bool>(
          label: 'Canjear',
          value: true,
          primary: true,
          icon: Icons.check_rounded,
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;
    await _redeem(context, ref, item);
  }

  Future<void> _redeem(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
  ) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.rpc('redeem_points_for_reward', params: {
        'p_reward_id': item['id'],
      });

      ref.invalidate(catalogProvider);
      ref.invalidate(clientGlobalPointsProvider);
      ref.invalidate(globalPointsProvider);
      ref.invalidate(pointsHistoryProvider);
      ref.invalidate(branchPointsProvider);
      ref.invalidate(clientWalletProvider);

      if (!context.mounted) return;
      HapticFeedback.mediumImpact();
      showLiquidToast(
        context,
        'Premio canjeado. Ya está en Mis premios.',
        tone: LiquidToastTone.success,
      );
      context.go('/rewards');
    } catch (e) {
      if (!context.mounted) return;
      showLiquidToast(
        context,
        _humanError(e),
        tone: LiquidToastTone.error,
        duration: const Duration(seconds: 4),
      );
    }
  }

  static String _humanError(Object e) {
    final raw = e is PostgrestException ? e.message : e.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('insuficiente') || lower.contains('insufficient')) {
      return 'No te alcanzan los puntos para este premio.';
    }
    if (lower.contains('stock') || lower.contains('agotado')) {
      return 'Este premio se agotó. Probá con otro.';
    }
    if (LiquidErrorState.isNetworkError(e)) {
      return 'Sin conexión. Revisá tu internet e intentá de nuevo.';
    }
    return 'No pudimos hacer el canje. Probá de nuevo en unos segundos.';
  }
}

// ---------------------------------------------------------------------------
// Encabezado de saldo
// ---------------------------------------------------------------------------
class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.points, required this.onRetry});

  final AsyncValue<int> points;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const green = MonacoColors.monacoGreen;
    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderRadius: 22,
      tint: green,
      tintOpacity: 0.07,
      pressable: false,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  green.withValues(alpha: 0.30),
                  green.withValues(alpha: 0.10),
                ],
              ),
              border: Border.all(color: green.withValues(alpha: 0.42), width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: green.withValues(alpha: 0.28),
                  blurRadius: 14,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: green, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu saldo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                points.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: LiquidSkeleton.line(width: 90, height: 22),
                  ),
                  error: (_, _) => Row(
                    children: [
                      Text(
                        '—',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      LiquidPill(
                        onTap: onRetry,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: const Text(
                          'Reintentar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  data: (value) => Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _pts.format(value),
                        style: const TextStyle(
                          color: MonacoColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -0.8,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          'pts',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          LiquidPill(
            onTap: () => context.push('/points'),
            padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Detalle',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de premio
// ---------------------------------------------------------------------------
class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.item,
    required this.userPoints,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final int userPoints;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cost = (item['points_cost'] as num?)?.toInt() ?? 0;
    final name = item['name'] as String? ?? 'Premio';
    final description = (item['description'] as String?)?.trim();
    final imageUrl = (item['image_url'] as String?)?.trim();
    final stock = (item['stock'] as num?)?.toInt();
    final outOfStock = stock != null && stock <= 0;
    final canRedeem = !outOfStock && userPoints >= cost;
    final progress = cost <= 0 ? 1.0 : (userPoints / cost).clamp(0.0, 1.0);

    return Opacity(
      opacity: canRedeem ? 1.0 : 0.72,
      child: LiquidGlass(
        onTap: onTap,
        padding: EdgeInsets.zero,
        borderRadius: 22,
        tintOpacity: canRedeem ? 0.08 : 0.045,
        showVignette: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Vista previa ──
              AspectRatio(
                aspectRatio: 1.28,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _RewardPreview(
                      imageUrl: imageUrl,
                      icon: _iconForItem(item),
                      accent: canRedeem
                          ? MonacoColors.monacoGreen
                          : Colors.white,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 40,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.35),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _CostPill(cost: cost, highlighted: canRedeem),
                    ),
                    if (outOfStock)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: LiquidStatusPill(
                          label: 'Agotado',
                          color: MonacoColors.occupancyClosed,
                          pulse: false,
                          compact: true,
                        ),
                      )
                    else if (!canRedeem)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.45),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.8,
                            ),
                          ),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Texto ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MonacoColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (canRedeem)
                        Row(
                          children: [
                            const LiquidStatusPill(
                              label: 'Te alcanza',
                              color: MonacoColors.monacoGreen,
                              pulse: false,
                              compact: true,
                            ),
                            const Spacer(),
                            Text(
                              'Canjear',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 1),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ],
                        )
                      else if (outOfStock)
                        Text(
                          'Sin stock por ahora',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else ...[
                        Text(
                          'Te faltan ${_pts.format(cost - userPoints)} pts',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _ProgressBar(value: progress),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconForItem(Map<String, dynamic> item) {
    if (item['is_free_service'] == true) return Icons.content_cut_rounded;
    final discount = item['discount_pct'];
    if (discount is num && discount > 0) return Icons.percent_rounded;
    return Icons.card_giftcard_rounded;
  }
}

class _RewardPreview extends StatelessWidget {
  const _RewardPreview({
    required this.imageUrl,
    required this.icon,
    required this.accent,
  });

  final String? imageUrl;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.30),
                accent.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.4), width: 0.8),
          ),
          child: Icon(icon, color: accent, size: 24),
        ),
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _CostPill extends StatelessWidget {
  const _CostPill({required this.cost, required this.highlighted});

  final int cost;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    const green = MonacoColors.monacoGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: highlighted
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [green, MonacoColors.monacoGreenDeep],
              )
            : LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.4),
                ],
              ),
        border: Border.all(
          color: highlighted
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: green.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Text(
        '${_pts.format(cost)} pts',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Colors.white.withValues(alpha: 0.08)),
            ),
            FractionallySizedBox(
              widthFactor: value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.7),
                      Colors.white.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vista previa dentro del diálogo de canje
// ---------------------------------------------------------------------------
class _RedeemPreview extends StatelessWidget {
  const _RedeemPreview({
    required this.item,
    required this.cost,
    required this.userPoints,
  });

  final Map<String, dynamic> item;
  final int cost;
  final int userPoints;

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? 'Premio';
    final imageUrl = (item['image_url'] as String?)?.trim();
    final remaining = userPoints - cost;
    final enough = remaining >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: _RewardPreview(
                imageUrl: imageUrl,
                icon: _CatalogCard._iconForItem(item),
                accent: MonacoColors.monacoGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cuesta ${_pts.format(cost)} pts',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enough
                      ? 'Te quedan ${_pts.format(remaining)} pts'
                      : 'Tenés ${_pts.format(userPoints)} pts',
                  style: TextStyle(
                    color: enough
                        ? MonacoColors.monacoGreen
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------
class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverToBoxAdapter(
            child: LiquidSkeleton(height: 76, radius: 22),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 48),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.70,
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
