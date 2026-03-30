import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';

class OccupancyScreen extends ConsumerWidget {
  const OccupancyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signals = ref.watch(branchSignalsProvider);

    return Scaffold(
      backgroundColor: MonacoColors.background,
      appBar: AppBar(
        title: const Text(
          'Sucursales',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: MonacoColors.background,
        foregroundColor: MonacoColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: MonacoColors.gold,
        backgroundColor: MonacoColors.surface,
        onRefresh: () async {
          ref.invalidate(branchSignalsProvider);
        },
        child: signals.when(
          data: (branches) {
            if (branches.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.store_outlined,
                        size: 56,
                        color: MonacoColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay sucursales disponibles',
                        style: TextStyle(
                          color: MonacoColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: branches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final b = branches[i];
                return _BranchCard(
                  data: b,
                  onTap: () => context.push('/branch/${b['branch_id']}'),
                ).animate(delay: (i * 80).ms).fadeIn(duration: 400.ms).slideY(
                      begin: 0.06,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOut,
                    );
              },
            );
          },
          loading: () => _buildShimmerList(),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: MonacoColors.destructive),
                  const SizedBox(height: 12),
                  Text(
                    'Error al cargar sucursales',
                    style: TextStyle(
                      color: MonacoColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(branchSignalsProvider),
                    child: Text(
                      'Reintentar',
                      style: TextStyle(color: MonacoColors.gold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => Container(
        height: 160,
        decoration: BoxDecoration(
          color: MonacoColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: Colors.white10),
    );
  }
}

// ── Branch Card ────────────────────────────────────────────────────────────

class _BranchCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _BranchCard({required this.data, required this.onTap});

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'alta':
        return const Color(0xFFEF4444);
      case 'media':
        return const Color(0xFFF59E0B);
      case 'sin_espera':
        return const Color(0xFF22C55E);
      case 'baja':
      default:
        return const Color(0xFF22C55E);
    }
  }

  String _levelLabel(String level) {
    switch (level.toLowerCase()) {
      case 'alta':
        return 'Ocupación alta';
      case 'media':
        return 'Ocupación media';
      case 'sin_espera':
        return 'Sin espera';
      case 'baja':
      default:
        return 'Ocupación baja';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = data['branch_name'] ?? 'Sucursal';
    final level = (data['occupancy_level'] ?? 'baja') as String;
    final isOpen = data['is_open'] ?? true;
    final waitingCount = (data['waiting_count'] ?? 0).toInt();
    final inProgressCount = (data['in_progress_count'] ?? 0).toInt();
    final availableBarbers = (data['available_barbers'] ?? 0).toInt();
    final totalBarbers = (data['total_barbers'] ?? 0).toInt();
    final eta = (data['eta_minutes'] ?? 0).toInt();
    final color = _levelColor(level);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: MonacoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MonacoColors.divider.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + status badge + arrow
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: MonacoColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusBadge(isOpen: isOpen),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: MonacoColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Occupancy indicator
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _levelLabel(level),
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Stats row
            Row(
              children: [
                _StatChip(
                  icon: Icons.hourglass_top_rounded,
                  label: '$waitingCount esperando',
                ),
                const SizedBox(width: 16),
                _StatChip(
                  icon: Icons.content_cut_rounded,
                  label: '$inProgressCount en progreso',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatChip(
                  icon: Icons.person_rounded,
                  label: '$availableBarbers / $totalBarbers barberos',
                ),
                const SizedBox(width: 16),
                _StatChip(
                  icon: Icons.schedule_rounded,
                  label: eta > 0 ? '~$eta min' : 'Sin espera',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status Badge ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isOpen;

  const _StatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen
            ? const Color(0xFF22C55E).withOpacity(0.15)
            : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOpen ? 'Abierto' : 'Cerrado',
        style: TextStyle(
          color: isOpen ? const Color(0xFF22C55E) : Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Stat Chip ──────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: MonacoColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: MonacoColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
