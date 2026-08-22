import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/points/presentation/widgets/points_history_tile.dart';
import 'package:monaco_mobile/features/points/providers/points_provider.dart';

final _pts = NumberFormat.decimalPattern('es_AR');

/// Pantalla "Mis puntos": saldo global, acceso al catálogo de canje,
/// desglose por sucursal e historial de movimientos. Vive fuera del shell.
class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(globalPointsProvider);
    ref.invalidate(pointsHistoryProvider);
    ref.invalidate(branchPointsProvider);
    // Esperamos el saldo (lo principal) para que el indicador no se cierre
    // antes de que haya datos nuevos; los errores los pinta la pantalla.
    await ref.read(globalPointsProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalPoints = ref.watch(globalPointsProvider);
    final history = ref.watch(pointsHistoryProvider);
    final branchPoints = ref.watch(branchPointsProvider);

    return LiquidAppBarScaffold(
      title: 'Mis puntos',
      showBackButton: true,
      body: globalPoints.when(
        loading: () => const _LoadingBody(),
        error: (e, _) => LiquidErrorState(
          error: e,
          onRetry: () => _refresh(ref),
        ),
        data: (data) {
          final total = (data['total_balance'] as num?)?.toInt() ?? 0;
          final earned = (data['total_earned'] as num?)?.toInt() ?? 0;
          final redeemed = (data['total_redeemed'] as num?)?.toInt() ?? 0;

          return RefreshIndicator(
            color: Colors.white,
            backgroundColor: MonacoColors.surface,
            onRefresh: () => _refresh(ref),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BalanceHero(
                    total: total,
                    earned: earned,
                    redeemed: redeemed,
                  ).liquidEnter(index: 0),
                  const SizedBox(height: 14),
                  LiquidButton(
                    onPressed: () => context.push('/catalog'),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.redeem_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Canjear puntos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ).liquidEnter(index: 1),
                  const SizedBox(height: 28),

                  // ── Por sucursal ──
                  const LiquidSectionTitle(
                    title: 'Por sucursal',
                    subtitle: 'Tus puntos en cada local',
                  ).liquidEnter(index: 2),
                  const SizedBox(height: 12),
                  _BranchSection(
                    branchPoints: branchPoints,
                    onRetry: () => ref.invalidate(branchPointsProvider),
                  ).liquidEnter(index: 3),
                  const SizedBox(height: 28),

                  // ── Historial ──
                  const LiquidSectionTitle(
                    title: 'Historial',
                    subtitle: 'Últimos movimientos',
                  ).liquidEnter(index: 4),
                  const SizedBox(height: 12),
                  _HistorySection(
                    history: history,
                    onRetry: () => ref.invalidate(pointsHistoryProvider),
                  ).liquidEnter(index: 5),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO DE SALDO
// ═══════════════════════════════════════════════════════════════════════════

class _BalanceHero extends StatelessWidget {
  final int total;
  final int earned;
  final int redeemed;

  const _BalanceHero({
    required this.total,
    required this.earned,
    required this.redeemed,
  });

  @override
  Widget build(BuildContext context) {
    const green = MonacoColors.monacoGreen;
    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      borderRadius: 26,
      tintOpacity: 0.09,
      pressable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      green.withValues(alpha: 0.28),
                      green.withValues(alpha: 0.10),
                    ],
                  ),
                  border: Border.all(
                    color: green.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: green.withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: green, size: 17),
              ),
              const SizedBox(width: 10),
              Text(
                'Puntos disponibles',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: total),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (_, value, _) => Text(
                  _pts.format(value),
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -1.8,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'pts',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.10)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: Icons.trending_up_rounded,
                  color: green,
                  value: '+${_pts.format(earned)}',
                  label: 'Ganados',
                ),
              ),
              Container(
                width: 0.5,
                height: 38,
                color: Colors.white.withValues(alpha: 0.10),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _HeroStat(
                  icon: Icons.card_giftcard_rounded,
                  color: Colors.white,
                  value: _pts.format(redeemed),
                  label: 'Canjeados',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _HeroStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.22),
                color.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color == Colors.white ? MonacoColors.textPrimary : color,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// POR SUCURSAL
// ═══════════════════════════════════════════════════════════════════════════

class _BranchSection extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> branchPoints;
  final VoidCallback onRetry;

  const _BranchSection({required this.branchPoints, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return branchPoints.when(
      loading: () => SizedBox(
        height: 108,
        child: Row(
          children: const [
            Expanded(child: LiquidSkeleton(height: 108, radius: 18)),
            SizedBox(width: 10),
            Expanded(child: LiquidSkeleton(height: 108, radius: 18)),
          ],
        ),
      ),
      error: (e, _) => _InlineError(
        message: 'No pudimos cargar tus puntos por sucursal.',
        onRetry: onRetry,
      ),
      data: (branches) {
        if (branches.isEmpty) {
          return const _InlineNote(
            icon: Icons.storefront_outlined,
            text: 'Todavía no sumaste puntos en ninguna sucursal.',
          );
        }
        return SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: branches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final b = branches[i];
              final branchData = b['branches'] as Map<String, dynamic>?;
              final name = branchData?['name']?.toString() ?? 'Sucursal';
              final balance = (b['points_balance'] as num?)?.toInt() ?? 0;
              final earned = (b['total_earned'] as num?)?.toInt() ?? 0;
              return _BranchPointsCard(
                name: name,
                balance: balance,
                earned: earned,
              ).liquidEnter(index: i, stagger: 70);
            },
          ),
        );
      },
    );
  }
}

class _BranchPointsCard extends StatelessWidget {
  final String name;
  final int balance;
  final int earned;

  const _BranchPointsCard({
    required this.name,
    required this.balance,
    required this.earned,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      width: 160,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      borderRadius: 18,
      tintOpacity: 0.06,
      pressable: false,
      showVignette: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_rounded,
                  size: 13, color: Colors.white.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _pts.format(balance),
                style: const TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.6,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'pts',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Acumulados ${_pts.format(earned)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
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
// HISTORIAL
// ═══════════════════════════════════════════════════════════════════════════

class _HistorySection extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> history;
  final VoidCallback onRetry;

  const _HistorySection({required this.history, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return history.when(
      loading: () => const LiquidSkeleton(height: 240, radius: 24),
      error: (e, _) => _InlineError(
        message: 'No pudimos cargar el historial.',
        onRetry: onRetry,
      ),
      data: (txns) {
        if (txns.isEmpty) {
          return const LiquidEmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'Sin movimientos todavía',
            message: 'Cada visita suma puntos. Acá vas a ver el detalle.',
            scrollable: false,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          );
        }
        return LiquidSectionCard(
          children: [
            for (final t in txns) PointsHistoryTile(transaction: t),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PIEZAS AUXILIARES
// ═══════════════════════════════════════════════════════════════════════════

class _InlineNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InlineNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderRadius: 16,
      tintOpacity: 0.05,
      pressable: false,
      showVignette: false,
      blur: LiquidTokens.blurSubtle,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 16,
      tint: MonacoColors.destructive,
      tintOpacity: 0.07,
      pressable: false,
      showVignette: false,
      blur: LiquidTokens.blurSubtle,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: MonacoColors.destructive),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          LiquidPill(
            onTap: onRetry,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: const Text(
              'Reintentar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      children: const [
        LiquidSkeleton(height: 232, radius: 26),
        SizedBox(height: 14),
        LiquidSkeleton(height: 52, radius: 16),
        SizedBox(height: 28),
        LiquidSkeleton.line(width: 140, height: 18),
        SizedBox(height: 14),
        SizedBox(
          height: 108,
          child: Row(
            children: [
              Expanded(child: LiquidSkeleton(height: 108, radius: 18)),
              SizedBox(width: 10),
              Expanded(child: LiquidSkeleton(height: 108, radius: 18)),
            ],
          ),
        ),
        SizedBox(height: 28),
        LiquidSkeleton.line(width: 110, height: 18),
        SizedBox(height: 14),
        LiquidSkeleton(height: 240, radius: 24),
      ],
    );
  }
}
