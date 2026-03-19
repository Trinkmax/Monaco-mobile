import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/features/home/presentation/widgets/points_card.dart';
import 'package:monaco_mobile/features/home/presentation/widgets/occupancy_mini_card.dart';
import 'package:monaco_mobile/features/points/providers/points_provider.dart';
import 'package:monaco_mobile/features/reviews/providers/reviews_provider.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';

// ── Providers ──────────────────────────────────────────────────────────────
// globalPointsProvider  → imported from points_provider.dart
// pendingReviewsProvider → imported from reviews_provider.dart
// branchSignalsProvider  → imported from occupancy_provider.dart

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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final points = ref.watch(globalPointsProvider);
    final reviews = ref.watch(pendingReviewsProvider);
    final branches = ref.watch(branchSignalsProvider);
    final billboard = ref.watch(billboardProvider);

    final userName = auth.clientName ?? 'Cliente';
    final today = DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.now());

    return Scaffold(
      backgroundColor: MonacoColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: MonacoColors.gold,
          backgroundColor: MonacoColors.surface,
          onRefresh: () async {
            ref.invalidate(globalPointsProvider);
            ref.invalidate(pendingReviewsProvider);
            ref.invalidate(branchSignalsProvider);
            ref.invalidate(billboardProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                _Header(name: userName, date: today),
                const SizedBox(height: 24),

                // ── Points Card ──
                points.when(
                  data: (data) => PointsCard(
                    totalBalance: (data['total_balance'] ?? 0).toInt(),
                    totalEarned: (data['total_earned'] ?? 0).toInt(),
                    onTap: () => context.push('/points'),
                  ),
                  loading: () => _shimmerCard(height: 140),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),

                // ── Pending Reviews Banner ──
                reviews.when(
                  data: (list) {
                    if (list.isEmpty) return const SizedBox.shrink();
                    return _ReviewBanner(
                      count: list.length,
                      onTap: () => context.push('/reviews'),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                if (reviews.valueOrNull != null &&
                    reviews.valueOrNull!.isNotEmpty)
                  const SizedBox(height: 20),

                // ── Branches Quick View ──
                Text(
                  'Sucursales',
                  style: TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: branches.when(
                    data: (list) {
                      if (list.isEmpty) {
                        return Center(
                          child: Text(
                            'Sin sucursales disponibles',
                            style: TextStyle(color: MonacoColors.textSecondary),
                          ),
                        );
                      }
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final b = list[i];
                          return GestureDetector(
                            onTap: () =>
                                context.push('/branch/${b['branch_id']}'),
                            child: OccupancyMiniCard(
                              branchName: b['branch_name'] ?? 'Sucursal',
                              occupancyLevel: b['occupancy_level'] ?? 'baja',
                              etaMinutes: (b['eta_minutes'] ?? 0).toInt(),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, __) => _shimmerCard(
                        width: 140,
                        height: 120,
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Billboard Carousel ──
                billboard.when(
                  data: (items) {
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cartelera',
                          style: TextStyle(
                            color: MonacoColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) {
                              final item = items[i];
                              return _BillboardCard(
                                title: item['title'] ?? '',
                                subtitle: item['subtitle'] ?? '',
                                imageUrl: item['image_url'],
                                onTap: () => _handleBillboardTap(
                                    context, item),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── Quick Actions ──
                Text(
                  'Accesos rápidos',
                  style: TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _QuickAction(
                      icon: Icons.menu_book_rounded,
                      label: 'Catálogo',
                      onTap: () => context.push('/catalog'),
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.emoji_events_rounded,
                      label: 'Mis Premios',
                      onTap: () => context.push('/rewards'),
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.history_rounded,
                      label: 'Historial',
                      onTap: () => context.push('/points'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleBillboardTap(BuildContext context, Map<String, dynamic> item) {
    final linkType = item['link_type'] as String?;
    final linkValue = item['link_value'] as String?;
    if (linkType == null || linkValue == null) return;
    switch (linkType) {
      case 'route':
        context.push(linkValue);
        break;
      case 'url':
        // Could launch URL externally
        break;
      case 'branch':
        context.push('/branch/$linkValue');
        break;
    }
  }
}

// ── Header Widget ──────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String name;
  final String date;

  const _Header({required this.name, required this.date});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hola, $name',
          style: TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideX(begin: -0.05, end: 0, duration: 500.ms),
        const SizedBox(height: 4),
        Text(
          date,
          style: TextStyle(
            color: MonacoColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
      ],
    );
  }
}

// ── Review Banner ──────────────────────────────────────────────────────────

class _ReviewBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ReviewBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: MonacoColors.gold.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MonacoColors.gold.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: MonacoColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tenés reseñas pendientes',
                style: TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              'Dejá tu opinión',
              style: TextStyle(
                color: MonacoColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 12, color: MonacoColors.gold),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms);
  }
}

// ── Billboard Card ─────────────────────────────────────────────────────────

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: MonacoColors.surface,
          borderRadius: BorderRadius.circular(16),
          image: imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(imageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.45),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              title,
              style: TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: MonacoColors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Action ───────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: MonacoColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: MonacoColors.divider.withOpacity(0.15),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: MonacoColors.gold, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }
}

// ── Shimmer Helper ─────────────────────────────────────────────────────────

Widget _shimmerCard({double? width, double height = 140}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: MonacoColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
  )
      .animate(onPlay: (c) => c.repeat())
      .shimmer(duration: 1200.ms, color: Colors.white10);
}
