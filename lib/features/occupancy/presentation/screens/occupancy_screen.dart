import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';

/// Tab "Sucursales" del dock: estado en vivo de cada local. Vive dentro del
/// shell (sin botón atrás, padding inferior para el dock).
class OccupancyScreen extends ConsumerWidget {
  const OccupancyScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(branchSignalsProvider);
    await ref.read(branchSignalsProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signals = ref.watch(branchSignalsProvider);

    return LiquidAppBarScaffold(
      title: 'Sucursales',
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: MonacoColors.surface,
        onRefresh: () => _refresh(ref),
        child: signals.when(
          data: (branches) {
            if (branches.isEmpty) {
              return const LiquidEmptyState(
                icon: Icons.storefront_outlined,
                title: 'No hay sucursales disponibles',
                message: 'Cuando haya locales activos los vas a ver acá.',
                padding: EdgeInsets.fromLTRB(32, 72, 32, 120),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              itemCount: branches.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: LiquidSectionTitle(
                      title: 'Estado en vivo',
                      subtitle: 'Elegí a dónde ir según la espera',
                    ),
                  ).liquidEnter(index: 0);
                }
                final b = branches[i - 1];
                return _BranchCard(
                  data: b,
                  onTap: () => context.push('/branch/${b['branch_id']}'),
                ).liquidEnter(index: i);
              },
            );
          },
          loading: () => const LiquidSkeletonList(
            count: 3,
            itemHeight: 184,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 120),
            gap: 14,
          ),
          error: (e, _) => LiquidErrorState(
            error: e,
            onRetry: () => _refresh(ref),
          ),
        ),
      ),
    );
  }
}

// ── Nivel de ocupación (una sola paleta para toda la app) ──────────────────

Color _levelColor(String level, bool effectivelyClosed) {
  if (effectivelyClosed) return MonacoColors.occupancyClosed;
  switch (level.toLowerCase()) {
    case 'alta':
      return MonacoColors.occupancyHigh;
    case 'media':
      return MonacoColors.occupancyMedium;
    case 'baja':
      return MonacoColors.occupancyLow;
    case 'sin_espera':
    default:
      return MonacoColors.occupancyNone;
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

// ── Branch card ─────────────────────────────────────────────────────────────

class _BranchCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _BranchCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = data['branch_name']?.toString() ?? 'Sucursal';
    final level = (data['occupancy_level'] ?? 'baja').toString();
    final isOpen = (data['is_open'] ?? true) as bool;
    final waitingCount = (data['waiting_count'] as num? ?? 0).toInt();
    final inProgressCount = (data['in_progress_count'] as num? ?? 0).toInt();
    final availableBarbers = (data['available_barbers'] as num? ?? 0).toInt();
    final totalBarbers = (data['total_barbers'] as num? ?? 0).toInt();

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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                color: Colors.white.withValues(alpha: 0.35),
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

          // Stats
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.hourglass_top_rounded,
                  label: '$waitingCount',
                  caption: 'esperando',
                  color: MonacoColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.content_cut_rounded,
                  label: '$inProgressCount',
                  caption: 'en curso',
                  color: MonacoColors.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.person_rounded,
                  label: '$availableBarbers/$totalBarbers',
                  caption: 'barberos',
                  color: MonacoColors.monacoGreen,
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
    return LiquidStatusPill(
      label: isOpen ? 'Abierto' : 'Cerrado',
      color: isOpen ? MonacoColors.monacoGreen : MonacoColors.occupancyClosed,
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
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.8),
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
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
