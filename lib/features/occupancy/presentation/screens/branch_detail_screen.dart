import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';
import 'package:monaco_mobile/features/occupancy/presentation/widgets/barber_status_tile.dart';

class BranchDetailScreen extends ConsumerWidget {
  final String branchId;

  const BranchDetailScreen({super.key, required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(branchDetailProvider(branchId));
    // Escuchar actualizaciones en tiempo real para invalidar el detalle
    ref.listen(branchQueueRealtimeProvider(branchId), (_, __) {
      ref.invalidate(branchDetailProvider(branchId));
    });

    return Scaffold(
      backgroundColor: MonacoColors.background,
      appBar: AppBar(
        backgroundColor: MonacoColors.background,
        foregroundColor: MonacoColors.textPrimary,
        elevation: 0,
        // Línea divisoria sutil en la parte inferior del AppBar
        shape: const Border(
          bottom: BorderSide(color: Colors.white10),
        ),
        title: detail.when(
          data: (d) => Text(
            d['branch']?['name'] ?? 'Sucursal',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          loading: () => const Text('Cargando...',
              style: TextStyle(fontWeight: FontWeight.w800)),
          error: (_, __) => const Text('Error',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      body: detail.when(
        data: (data) => _BranchDetailContent(data: data),
        loading: () => _buildShimmer(),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: MonacoColors.destructive),
              const SizedBox(height: 12),
              Text(
                'Error al cargar detalle',
                style: TextStyle(color: MonacoColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(branchDetailProvider(branchId)),
                child:
                    Text('Reintentar', style: TextStyle(color: MonacoColors.gold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              height: 80,
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
}

// ── Contenido principal del detalle ────────────────────────────────────────

class _BranchDetailContent extends StatelessWidget {
  final Map<String, dynamic> data;

  const _BranchDetailContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final branch = data['branch'] as Map<String, dynamic>? ?? {};
    final waiting = (data['waiting'] ?? []) as List;
    final inProgress = (data['in_progress'] ?? []) as List;
    final staff = (data['staff'] ?? []) as List;
    final availableCount = (data['available_staff_count'] ?? 0) as int;
    final totalBarbers =
        data['total_staff_count'] as int? ?? staff.length;
    final isOpen = data['is_open'] == true;
    final openTime = data['business_hours_open'] ?? '--:--';
    final closeTime = data['business_hours_close'] ?? '--:--';
    final branchLat = (branch['latitude'] as num?)?.toDouble();
    final branchLng = (branch['longitude'] as num?)?.toDouble();
    final branchAddress = branch['address'] as String?;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Indicador en vivo ──
          _LiveIndicator(isOpen: isOpen)
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 20),

          // ── Tarjetas de resumen ──
          _SummaryCard(
            waitingCount: waiting.length,
            inProgressCount: inProgress.length,
            availableBarbers: availableCount,
          ).animate().fadeIn(duration: 500.ms).slideY(
                begin: 0.05,
                end: 0,
                duration: 500.ms,
              ),
          const SizedBox(height: 16),

          // ── Tarjeta de ocupación ──
          _OccupancyCard(
            waitingCount: waiting.length,
            availableBarbers: availableCount,
            totalBarbers: totalBarbers,
          )
              .animate(delay: 100.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms),
          const SizedBox(height: 16),

          // ── Horario ──
          _ScheduleRow(openTime: openTime, closeTime: closeTime)
              .animate(delay: 150.ms)
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 12),

          // ── Dirección + Cómo llegar ──
          if (branchAddress != null || (branchLat != null && branchLng != null))
            _DirectionsRow(
              address: branchAddress,
              latitude: branchLat,
              longitude: branchLng,
            )
                .animate(delay: 200.ms)
                .fadeIn(duration: 400.ms),
          const SizedBox(height: 24),

          // ── Encabezado de barberos ──
          Row(
            children: [
              Text(
                'Barberos',
                style: TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: MonacoColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalBarbers',
                  style: TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (staff.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Sin barberos registrados',
                  style: TextStyle(color: MonacoColors.textSecondary),
                ),
              ),
            )
          else
            ...staff.asMap().entries.map((entry) {
              final i = entry.key;
              final s = Map<String, dynamic>.from(entry.value as Map);
              final currentClient = s['current_client'] as Map<String, dynamic>?;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BarberStatusTile(
                  name: s['full_name'] ?? 'Barbero',
                  status: s['status'] ?? 'disponible',
                  avatarUrl: s['avatar_url'] as String?,
                  currentClientName: currentClient?['client_name'],
                  etaMinutes: s['eta_minutes'] as int?,
                  queueAhead: (s['waiting_count'] as int?) ?? 0,
                )
                    .animate(delay: (200 + i * 60).ms)
                    .fadeIn(duration: 350.ms)
                    .slideX(begin: 0.04, end: 0, duration: 350.ms),
              );
            }),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Indicador en vivo ───────────────────────────────────────────────────────

class _LiveIndicator extends StatelessWidget {
  final bool isOpen;

  const _LiveIndicator({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    if (!isOpen) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'CERRADO',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.5, duration: 800.ms)
              .then()
              .scaleXY(begin: 1.5, end: 1.0, duration: 800.ms),
          const SizedBox(width: 8),
          const Text(
            'EN VIVO',
            style: TextStyle(
              color: Color(0xFF22C55E),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjetas de resumen ─────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int waitingCount;
  final int inProgressCount;
  final int availableBarbers;

  const _SummaryCard({
    required this.waitingCount,
    required this.inProgressCount,
    required this.availableBarbers,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            icon: Icons.hourglass_top_rounded,
            value: '$waitingCount',
            label: 'En espera',
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            icon: Icons.content_cut_rounded,
            value: '$inProgressCount',
            label: 'En progreso',
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            icon: Icons.check_circle_outline_rounded,
            value: '$availableBarbers',
            label: 'Disponibles',
            color: const Color(0xFF22C55E),
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: MonacoColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de ocupación ────────────────────────────────────────────────────

class _OccupancyCard extends StatelessWidget {
  final int waitingCount;
  final int availableBarbers;
  final int totalBarbers;

  const _OccupancyCard({
    required this.waitingCount,
    required this.availableBarbers,
    required this.totalBarbers,
  });

  String get _levelKey {
    if (availableBarbers >= 1) return 'sin_espera';
    if (waitingCount == 0) return 'baja';
    if (totalBarbers == 0 || waitingCount < 2 * totalBarbers) return 'media';
    return 'alta';
  }

  Color get _levelColor {
    switch (_levelKey) {
      case 'alta':
        return MonacoColors.occupancyHigh;
      case 'media':
        return MonacoColors.occupancyMedium;
      case 'sin_espera':
      case 'baja':
      default:
        return MonacoColors.occupancyLow;
    }
  }

  String get _levelLabel {
    switch (_levelKey) {
      case 'alta':
        return 'ALTA';
      case 'media':
        return 'MEDIA';
      case 'sin_espera':
        return 'SIN ESPERA';
      case 'baja':
      default:
        return 'BAJA';
    }
  }

  // Ratio visual para la barra de progreso: llena al 100% cuando waiting = 2 por barbero
  double get _ratio {
    if (totalBarbers == 0) return 0.0;
    return (waitingCount / (2.0 * totalBarbers)).clamp(0.0, 1.0);
  }

  String get _subtitle {
    if (availableBarbers >= 1) {
      return '$availableBarbers barbero${availableBarbers > 1 ? "s" : ""} disponible${availableBarbers > 1 ? "s" : ""}';
    }
    if (waitingCount == 0) return 'Todos atendiendo, sin cola';
    return '$waitingCount en espera · $availableBarbers disponibles';
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _ratio;
    final color = _levelColor;
    final label = _levelLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MonacoColors.divider.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado: título + badge de nivel
          Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  size: 18, color: MonacoColors.gold),
              const SizedBox(width: 8),
              Text(
                'Ocupación',
                style: TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barra de progreso con gradiente
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  // Fondo
                  Container(
                    width: double.infinity,
                    color: Colors.white10,
                  ),
                  // Relleno coloreado
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.7),
                            color,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Subtítulo debajo de la barra
          Text(
            _subtitle,
            style: TextStyle(
              color: MonacoColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Horario ─────────────────────────────────────────────────────────────────

class _ScheduleRow extends StatelessWidget {
  final String openTime;
  final String closeTime;

  const _ScheduleRow({required this.openTime, required this.closeTime});

  /// Elimina los segundos de HH:MM:SS → HH:MM
  String _formatTime(String t) {
    final parts = t.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MonacoColors.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded,
              size: 16, color: MonacoColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            'Horario: ${_formatTime(openTime)} - ${_formatTime(closeTime)}',
            style: TextStyle(
              color: MonacoColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dirección + Cómo llegar ───────────────────────────────────────────────

class _DirectionsRow extends StatelessWidget {
  final String? address;
  final double? latitude;
  final double? longitude;

  const _DirectionsRow({
    this.address,
    this.latitude,
    this.longitude,
  });

  Future<void> _openMaps() async {
    if (latitude == null || longitude == null) return;
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MonacoColors.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined,
              size: 16, color: MonacoColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              address ?? 'Ubicación disponible',
              style: TextStyle(
                color: MonacoColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (latitude != null && longitude != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _openMaps,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: MonacoColors.gold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_rounded,
                        size: 14, color: Colors.black),
                    SizedBox(width: 4),
                    Text(
                      'Cómo llegar',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
