import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';

class OccupancyScreen extends ConsumerWidget {
  const OccupancyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signals = ref.watch(branchSignalsProvider);

    return LiquidAppBarScaffold(
      title: 'Sucursales',
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: MonacoColors.surface,
        onRefresh: () async {
          ref.invalidate(branchSignalsProvider);
        },
        child: signals.when(
          data: (branches) {
            if (branches.isEmpty) {
              return _EmptyBranches();
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
              itemCount: branches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final b = branches[i];
                return _BranchCard(
                  data: b,
                  onTap: () => context.push('/branch/${b['branch_id']}'),
                ).liquidEnter(index: i);
              },
            );
          },
          loading: () => _shimmerList(),
          error: (e, _) => _ErrorBranches(
            onRetry: () => ref.invalidate(branchSignalsProvider),
          ),
        ),
      ),
    );
  }
}

// ── Branch card ─────────────────────────────────────────────────────────────

class _BranchCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _BranchCard({required this.data, required this.onTap});

  Color _levelColor(String level, bool effectivelyClosed) {
    if (effectivelyClosed) return const Color(0xFF6B6B6B);
    switch (level.toLowerCase()) {
      case 'alta':
        return const Color(0xFFEF4444);
      case 'media':
        return const Color(0xFFF59E0B);
      case 'baja':
        return const Color(0xFF84CC16);
      case 'sin_espera':
      default:
        return LiquidTokens.monacoGreen;
    }
  }

  String _levelLabel(String level, bool effectivelyClosed) {
    if (effectivelyClosed) return 'Cerrado';
    switch (level.toLowerCase()) {
      case 'alta':
        return 'Alta demanda';
      case 'media':
        return 'Movimiento moderado';
      case 'baja':
        return 'Espera corta';
      case 'sin_espera':
      default:
        return 'Sin espera';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = data['branch_name'] ?? 'Sucursal';
    final level = (data['occupancy_level'] ?? 'baja') as String;
    final isOpen = (data['is_open'] ?? true) as bool;
    final waitingCount = (data['waiting_count'] ?? 0).toInt();
    final inProgressCount = (data['in_progress_count'] ?? 0).toInt();
    final availableBarbers = (data['available_barbers'] ?? 0).toInt();
    final totalBarbers = (data['total_barbers'] ?? 0).toInt();

    final effectivelyClosed = !isOpen || totalBarbers == 0;
    final color = _levelColor(level, effectivelyClosed);

    return LiquidGlass(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      tint: color,
      tintOpacity: 0.06,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              _OpenClosedPill(isOpen: !effectivelyClosed),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.white.withOpacity(0.35),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Badge de ocupación — LED + label sobre glass
          LiquidStatusPill(
            label: _levelLabel(level, effectivelyClosed),
            color: color,
            pulse: !effectivelyClosed,
          ),
          const SizedBox(height: 16),

          // Grid de stats en 2x2
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.hourglass_top_rounded,
                  label: '$waitingCount',
                  caption: 'esperando',
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.content_cut_rounded,
                  label: '$inProgressCount',
                  caption: 'en curso',
                  color: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.person_rounded,
                  label: '$availableBarbers/$totalBarbers',
                  caption: 'barberos',
                  color: LiquidTokens.monacoGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpenClosedPill extends StatelessWidget {
  final bool isOpen;
  const _OpenClosedPill({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? LiquidTokens.monacoGreen : Colors.grey;
    return LiquidStatusPill(
      label: isOpen ? 'Abierto' : 'Cerrado',
      color: color,
      pulse: isOpen,
      compact: true,
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.caption,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.14),
            color.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22), width: 0.8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            caption,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty / error / shimmer ────────────────────────────────────────────────

class _EmptyBranches extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(
                Icons.store_outlined,
                size: 32,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No hay sucursales disponibles',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBranches extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBranches({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: MonacoColors.destructive),
            const SizedBox(height: 14),
            Text(
              'Error al cargar sucursales',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 14),
            LiquidPill(
              onTap: onRetry,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: const Text(
                'Reintentar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _shimmerList() {
  return ListView.separated(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
    itemCount: 3,
    separatorBuilder: (_, _) => const SizedBox(height: 14),
    itemBuilder: (_, _) => Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white10),
  );
}
