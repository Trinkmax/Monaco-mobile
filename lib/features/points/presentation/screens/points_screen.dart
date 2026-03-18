import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/points/providers/points_provider.dart';
import 'package:monaco_mobile/features/points/presentation/widgets/points_history_tile.dart';

class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalPoints = ref.watch(globalPointsProvider);
    final history = ref.watch(pointsHistoryProvider);
    final branchPoints = ref.watch(branchPointsProvider);

    return Scaffold(
      backgroundColor: MonacoColors.background,
      appBar: AppBar(
        title: const Text('Mis Puntos'),
        backgroundColor: MonacoColors.surface,
        foregroundColor: MonacoColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: MonacoColors.gold,
        onRefresh: () async {
          ref.invalidate(globalPointsProvider);
          ref.invalidate(pointsHistoryProvider);
          ref.invalidate(branchPointsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Balance card ---
              _buildBalanceCard(context, globalPoints),
              const SizedBox(height: 20),

              // --- Redeem button ---
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/catalog'),
                  icon: const Icon(Icons.redeem, color: MonacoColors.background),
                  label: const Text(
                    'Canjear puntos',
                    style: TextStyle(
                      color: MonacoColors.background,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MonacoColors.gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 400.ms)
                  .slideY(begin: 0.1, end: 0),
              const SizedBox(height: 28),

              // --- By branch ---
              _buildBranchSection(branchPoints),
              const SizedBox(height: 28),

              // --- History ---
              _buildHistorySection(history),
            ],
          ),
        ),
      ),
    );
  }

  // ───────── Balance card ─────────
  Widget _buildBalanceCard(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> globalPoints,
  ) {
    return globalPoints.when(
      loading: () => _shimmerCard(),
      error: (e, _) => _errorCard('Error al cargar puntos'),
      data: (data) {
        final total = data['total_points'] ?? 0;
        final earned = data['total_earned'] ?? 0;
        final redeemed = data['total_redeemed'] ?? 0;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1E2C), Color(0xFF2A2A3D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MonacoColors.gold.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: MonacoColors.gold.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            children: [
              const Icon(Icons.star_rounded, color: MonacoColors.gold, size: 48)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.15, 1.15),
                    duration: 1200.ms,
                  ),
              const SizedBox(height: 12),
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: MonacoColors.gold,
                  letterSpacing: -1,
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 4),
              Text(
                'puntos disponibles',
                style: TextStyle(
                  fontSize: 14,
                  color: MonacoColors.textSecondary.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statColumn('Ganados', '+$earned', Colors.green),
                  Container(width: 1, height: 36, color: Colors.white12),
                  _statColumn('Canjeados', '-$redeemed', Colors.redAccent),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.15, end: 0);
      },
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: MonacoColors.textSecondary.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // ───────── Branch section ─────────
  Widget _buildBranchSection(
    AsyncValue<List<Map<String, dynamic>>> branchPoints,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Por sucursal',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MonacoColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        branchPoints.when(
          loading: () => _shimmerRow(),
          error: (_, __) => const Text(
            'Error al cargar sucursales',
            style: TextStyle(color: MonacoColors.textSecondary),
          ),
          data: (branches) {
            if (branches.isEmpty) {
              return const Text(
                'Sin puntos por sucursal',
                style: TextStyle(color: MonacoColors.textSecondary),
              );
            }
            return SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: branches.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final b = branches[i];
                  final branchData = b['branches'] as Map<String, dynamic>?;
                  final name = branchData?['name'] ?? 'Sucursal';
                  final pts = b['points'] ?? 0;

                  return Container(
                    width: 140,
                    decoration: BoxDecoration(
                      color: MonacoColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: MonacoColors.gold.withOpacity(0.2)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MonacoColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$pts pts',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: MonacoColors.gold,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: (100 * i).ms, duration: 350.ms)
                      .slideX(begin: 0.15, end: 0);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  // ───────── History section ─────────
  Widget _buildHistorySection(
    AsyncValue<List<Map<String, dynamic>>> history,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historial',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MonacoColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        history.when(
          loading: () => Column(
            children: List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _shimmerTile(),
              ),
            ),
          ),
          error: (_, __) => const Text(
            'Error al cargar historial',
            style: TextStyle(color: MonacoColors.textSecondary),
          ),
          data: (txns) {
            if (txns.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long,
                        size: 48, color: MonacoColors.textSecondary.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    const Text(
                      'Sin transacciones aún',
                      style: TextStyle(color: MonacoColors.textSecondary),
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: txns.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                return PointsHistoryTile(transaction: txns[i])
                    .animate()
                    .fadeIn(delay: (60 * i).ms, duration: 300.ms)
                    .slideX(begin: 0.08, end: 0);
              },
            );
          },
        ),
      ],
    );
  }

  // ───────── Error card ─────────
  Widget _errorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 40, color: MonacoColors.destructive),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: MonacoColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ───────── Shimmer helpers ─────────
  Widget _shimmerCard() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white10);
  }

  Widget _shimmerRow() {
    return SizedBox(
      height: 100,
      child: Row(
        children: List.generate(
          3,
          (i) => Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
              decoration: BoxDecoration(
                color: MonacoColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 1200.ms, color: Colors.white10),
          ),
        ),
      ),
    );
  }

  Widget _shimmerTile() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white10);
  }
}
