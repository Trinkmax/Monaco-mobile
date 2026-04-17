import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/branch/selected_branch_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
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

    final userName = auth.clientName ?? 'Cliente';
    final today = DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.now());

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
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  _Header(name: userName, date: today),
                  const SizedBox(height: 14),

                  // ── Org + Sucursal ──
                  if (auth.selectedOrgName != null ||
                      selectedBranchName != null)
                    _OrgPill(
                      label: [
                        if (auth.selectedOrgName != null) auth.selectedOrgName!,
                        if (selectedBranchName != null) selectedBranchName,
                      ].join(' · '),
                      onTap: () {
                        ref.read(authProvider.notifier).clearSelectedOrg();
                        context.go('/select-org');
                      },
                    ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
                  const SizedBox(height: 22),

                  // ── Points Card ──
                  points.when(
                    data: (data) => PointsCard(
                      totalBalance: (data['total_balance'] ?? 0).toInt(),
                      totalEarned: (data['total_earned'] ?? 0).toInt(),
                      onTap: () => context.push('/points'),
                    ),
                    loading: () => _shimmerCard(height: 150),
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
                  _SectionTitle(
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
                                color: MonacoColors.textSecondary,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final b = list[i];
                            return OccupancyMiniCard(
                              branchName: b['branch_name'] ?? 'Sucursal',
                              occupancyLevel: b['occupancy_level'] ?? 'baja',
                              isOpen: (b['is_open'] ?? true) as bool,
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
                            _shimmerCard(width: 160, height: 128),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 26),

                  // ── Billboard ──
                  billboard.when(
                    data: (items) {
                      if (items.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle(
                            title: 'Cartelera',
                            subtitle: 'Novedades de la barbería',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
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
                          _SectionTitle(
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

                  // ── Quick Actions ──
                  const _SectionTitle(title: 'Accesos rápidos'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.menu_book_rounded,
                          label: 'Catálogo',
                          onTap: () => context.push('/catalog'),
                        ).liquidEnter(index: 0, stagger: 70),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.card_giftcard_rounded,
                          label: 'Mis Premios',
                          onTap: () => context.push('/rewards'),
                        ).liquidEnter(index: 1, stagger: 70),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.history_rounded,
                          label: 'Historial',
                          onTap: () => context.push('/points'),
                        ).liquidEnter(index: 2, stagger: 70),
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
    final linkValue = item['link_value'] as String?;
    if (linkType == null || linkValue == null) return;
    switch (linkType) {
      case 'route':
        context.push(linkValue);
        break;
      case 'url':
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
            color: Colors.white.withOpacity(0.55),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ORG PILL — glass pill con nombre de sucursal + chip "Cambiar"
// ═══════════════════════════════════════════════════════════════════════════

class _OrgPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OrgPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: LiquidPill(
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        onTap: onTap,
        borderRadius: 16,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_rounded,
                size: 15, color: Colors.white),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cambiar',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: Colors.white.withOpacity(0.75),
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
// SECTION TITLE
// ═══════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onAction != null && actionLabel != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: Colors.white.withOpacity(0.85),
                ),
              ],
            ),
          ),
      ],
    );
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
    const amber = Color(0xFFF5A623);
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
                  amber.withOpacity(0.28),
                  amber.withOpacity(0.14),
                ],
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: amber.withOpacity(0.42), width: 0.8),
            ),
            child: Center(
              child: Text(
                '$count',
                style: TextStyle(
                  color: amber.withOpacity(0.98),
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
              color: amber.withOpacity(0.98),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 11,
            color: amber.withOpacity(0.98),
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
                      Colors.black.withOpacity(0.65),
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
                      color: Colors.white.withOpacity(0.85),
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
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.06),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.22),
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
              color: Colors.white.withOpacity(0.5),
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
// QUICK ACTION — glass compacto con ícono y label
// ═══════════════════════════════════════════════════════════════════════════

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
    return LiquidGlass(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      borderRadius: 20,
      tintOpacity: 0.07,
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
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: Colors.white.withOpacity(0.22),
                width: 0.8,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHIMMER HELPER
// ═══════════════════════════════════════════════════════════════════════════

Widget _shimmerCard({double? width, double height = 140}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
  )
      .animate(onPlay: (c) => c.repeat())
      .shimmer(duration: 1400.ms, color: Colors.white10);
}
