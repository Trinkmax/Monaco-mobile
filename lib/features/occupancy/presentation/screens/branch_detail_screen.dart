import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';
import 'package:monaco_mobile/features/occupancy/presentation/widgets/barber_status_tile.dart';

class BranchDetailScreen extends ConsumerWidget {
  final String branchId;

  const BranchDetailScreen({super.key, required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(branchDetailProvider(branchId));
    // Listen to realtime updates to invalidate detail
    ref.listen(branchQueueRealtimeProvider(branchId), (_, __) {
      ref.invalidate(branchDetailProvider(branchId));
    });

    return Scaffold(
      backgroundColor: MonacoColors.background,
      appBar: AppBar(
        backgroundColor: MonacoColors.background,
        foregroundColor: MonacoColors.textPrimary,
        elevation: 0,
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
              Icon(Icons.error_outline, size: 48, color: MonacoColors.destructive),
              const SizedBox(height: 12),
              Text(
                'Error al cargar detalle',
                style: TextStyle(color: MonacoColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(branchDetailProvider(branchId)),
                child: Text('Reintentar',
                    style: TextStyle(color: MonacoColors.gold)),
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

// ── Detail Content ─────────────────────────────────────────────────────────

class _BranchDetailContent extends StatelessWidget {
  final Map<String, dynamic> data;

  const _BranchDetailContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final waiting = (data['waiting'] ?? []) as List;
    final inProgress = (data['in_progress'] ?? []) as List;
    final staff = (data['staff'] ?? []) as List;
    final availableCount = (data['available_staff_count'] ?? 0) as int;
    final isOpen = data['is_open'] == true;
    final openTime = data['business_hours_open'] ?? '--:--';
    final closeTime = data['business_hours_close'] ?? '--:--';
    final etaMinutes = (data['eta_minutes'] ?? 0) as int;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Live indicator ──
          _LiveIndicator(isOpen: isOpen)
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 20),

          // ── Summary Card ──
          _SummaryCard(
            waitingCount: waiting.length,
            inProgressCount: inProgress.length,
            availableBarbers: availableCount,
          ).animate().fadeIn(duration: 500.ms).slideY(
                begin: 0.05,
                end: 0,
                duration: 500.ms,
              ),
          const SizedBox(height: 20),

          // ── ETA ──
          _EtaSection(etaMinutes: etaMinutes)
              .animate(delay: 100.ms)
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 20),

          // ── Schedule ──
          _ScheduleRow(openTime: openTime, closeTime: closeTime)
              .animate(delay: 150.ms)
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 24),

          // ── Barbers ──
          Text(
            'Barberos',
            style: TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
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

// ── Live Indicator ─────────────────────────────────────────────────────────

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

// ── Summary Card ───────────────────────────────────────────────────────────

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MonacoColors.divider.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              value: '$waitingCount',
              label: 'En espera',
              color: const Color(0xFFF59E0B),
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _SummaryItem(
              value: '$inProgressCount',
              label: 'En progreso',
              color: const Color(0xFF3B82F6),
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _SummaryItem(
              value: '$availableBarbers',
              label: 'Disponibles',
              color: const Color(0xFF22C55E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: MonacoColors.divider.withOpacity(0.15),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SummaryItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: MonacoColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── ETA Section ────────────────────────────────────────────────────────────

class _EtaSection extends StatelessWidget {
  final int etaMinutes;

  const _EtaSection({required this.etaMinutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MonacoColors.divider.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded,
              size: 32, color: MonacoColors.gold),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tiempo estimado de espera',
                style: TextStyle(
                  color: MonacoColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                etaMinutes > 0 ? '~$etaMinutes minutos' : 'Sin espera',
                style: TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Schedule Row ───────────────────────────────────────────────────────────

class _ScheduleRow extends StatelessWidget {
  final String openTime;
  final String closeTime;

  const _ScheduleRow({required this.openTime, required this.closeTime});

  /// Strip seconds from HH:MM:SS → HH:MM
  String _formatTime(String t) {
    final parts = t.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MonacoColors.divider.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded,
              size: 20, color: MonacoColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            'Horario: ${_formatTime(openTime)} - ${_formatTime(closeTime)}',
            style: TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
