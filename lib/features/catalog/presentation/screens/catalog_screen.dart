import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/core/utils/formatters.dart';
import 'package:monaco_mobile/features/catalog/providers/catalog_provider.dart';

// ---------------------------------------------------------------------------
// Points provider (global balance)
// ---------------------------------------------------------------------------
final clientGlobalPointsProvider = FutureProvider<int>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.rpc('get_client_global_points');
  if (res is int) return res;
  if (res is Map && res.containsKey('points')) return res['points'] as int;
  return 0;
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCatalog = ref.watch(catalogProvider);
    final asyncPoints = ref.watch(clientGlobalPointsProvider);

    return Scaffold(
      backgroundColor: MonacoColors.background,
      appBar: AppBar(
        title: const Text('Catalogo de Canjes',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: MonacoColors.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: asyncCatalog.when(
        loading: () => _buildShimmerGrid(),
        error: (e, _) => Center(
          child:
              Text('Error: $e', style: const TextStyle(color: Colors.white70)),
        ),
        data: (items) {
          final userPoints = asyncPoints.valueOrNull ?? 0;
          return _CatalogBody(items: items, userPoints: userPoints);
        },
      ),
    );
  }

  // ---- Shimmer loading ----
  Widget _buildShimmerGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: MonacoColors.surface,
        highlightColor: MonacoColors.surface.withOpacity(0.6),
        child: GridView.builder(
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: MonacoColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body with header + grid
// ---------------------------------------------------------------------------
class _CatalogBody extends ConsumerWidget {
  const _CatalogBody({required this.items, required this.userPoints});

  final List<Map<String, dynamic>> items;
  final int userPoints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Points header
        SliverToBoxAdapter(
          child: _PointsHeader(userPoints: userPoints),
        ),

        // Grid
        if (items.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.card_giftcard_outlined,
                      size: 64, color: MonacoColors.gold.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  const Text('No hay premios disponibles',
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  return _CatalogCard(
                    item: item,
                    userPoints: userPoints,
                    index: index,
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Points header card
// ---------------------------------------------------------------------------
class _PointsHeader extends StatelessWidget {
  const _PointsHeader({required this.userPoints});

  final int userPoints;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MonacoColors.gold.withOpacity(0.25),
              MonacoColors.gold.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MonacoColors.gold.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MonacoColors.gold.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.stars_rounded,
                  color: MonacoColors.gold, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tu saldo',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.points(userPoints),
                    style: TextStyle(
                      color: MonacoColors.gold,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Text('pts',
                style: TextStyle(
                    color: MonacoColors.gold.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: -0.08),
    );
  }
}

// ---------------------------------------------------------------------------
// Single catalog card
// ---------------------------------------------------------------------------
class _CatalogCard extends ConsumerWidget {
  const _CatalogCard({
    required this.item,
    required this.userPoints,
    required this.index,
  });

  final Map<String, dynamic> item;
  final int userPoints;
  final int index;

  IconData _iconForItem() {
    if (item['is_free_service'] == true) return Icons.content_cut;
    final discount = item['discount_pct'];
    if (discount != null && (discount as num) > 0) return Icons.percent;
    return Icons.card_giftcard;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cost = (item['points_cost'] as num?)?.toInt() ?? 0;
    final name = item['name'] as String? ?? 'Premio';
    final description = item['description'] as String?;
    final canRedeem = userPoints >= cost;

    return Opacity(
      opacity: canRedeem ? 1.0 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: MonacoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canRedeem
                ? MonacoColors.gold.withOpacity(0.25)
                : Colors.white10,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: canRedeem
                ? () => _showRedeemDialog(context, ref, name, cost)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MonacoColors.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_iconForItem(),
                        color: MonacoColors.gold, size: 24),
                  ),
                  const SizedBox(height: 12),

                  // Name
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),

                  // Description
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Cost badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: MonacoColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$cost pts',
                      style: TextStyle(
                        color: MonacoColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Status badge / button
                  if (canRedeem)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Alcanzable',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Spacer(),
                        Text('Canjear',
                            style: TextStyle(
                                color: MonacoColors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Faltan ${cost - userPoints} pts',
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(delay: (80 * index).ms, duration: 400.ms)
          .slideY(begin: 0.08),
    );
  }

  // ---- Redeem dialog ----
  void _showRedeemDialog(
      BuildContext context, WidgetRef ref, String name, int cost) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MonacoColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar canje',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          '¿Canjear $name por $cost puntos?',
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MonacoColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _redeem(context, ref, cost);
            },
            child: const Text('Confirmar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _redeem(BuildContext context, WidgetRef ref, int cost) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.rpc('redeem_points_for_reward', params: {
        'p_reward_id': item['id'],
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Premio canjeado!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      ref.invalidate(catalogProvider);
      ref.invalidate(clientGlobalPointsProvider);
      context.go('/rewards');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
