import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';
import 'package:monaco_mobile/features/occupancy/presentation/widgets/barber_flow_tile.dart';

class BranchDetailScreen extends ConsumerWidget {
  final String branchId;

  const BranchDetailScreen({super.key, required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(branchDetailProvider(branchId));

    // Escuchar actualizaciones en tiempo real de cola y asistencia
    ref.listen(branchQueueRealtimeProvider(branchId), (_, __) {
      ref.invalidate(branchDetailProvider(branchId));
    });
    ref.listen(branchAttendanceRealtimeProvider(branchId), (_, __) {
      ref.invalidate(branchDetailProvider(branchId));
    });

    return Scaffold(
      backgroundColor: MonacoColors.background,
      appBar: AppBar(
        backgroundColor: MonacoColors.background,
        foregroundColor: MonacoColors.textPrimary,
        elevation: 0,
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
        data: (data) => _LiveQueueContent(data: data),
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
        children: [
          // Shimmer header
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: MonacoColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1200.ms, color: Colors.white10),
          const SizedBox(height: 16),
          // Shimmer stats
          Row(
            children: List.generate(
              3,
              (_) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: MonacoColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 1200.ms, color: Colors.white10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Shimmer tiles
          ...List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: MonacoColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 1200.ms, color: Colors.white10),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contenido principal: Fila en vivo ──────────────────────────────────────

class _LiveQueueContent extends StatelessWidget {
  final Map<String, dynamic> data;

  const _LiveQueueContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final branch = data['branch'] as Map<String, dynamic>? ?? {};
    final waiting = (data['waiting'] ?? []) as List;
    final inProgress = (data['in_progress'] ?? []) as List;
    final staff = (data['staff'] ?? []) as List;
    final availableCount = (data['available_staff_count'] ?? 0) as int;
    final totalBarbers = data['total_staff_count'] as int? ?? staff.length;
    final isOpen = data['is_open'] == true;
    final openTime = data['business_hours_open'] ?? '--:--';
    final closeTime = data['business_hours_close'] ?? '--:--';
    final branchLat = (branch['latitude'] as num?)?.toDouble();
    final branchLng = (branch['longitude'] as num?)?.toDouble();
    final branchAddress = branch['address'] as String?;

    return RefreshIndicator(
      color: MonacoColors.gold,
      backgroundColor: MonacoColors.surface,
      onRefresh: () async {
        // El invalidate se hace desde el ConsumerWidget padre
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Estado en vivo + ETA global ──
            _LiveHeader(
              isOpen: isOpen,
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 16),

            // ── Resumen rápido: 3 métricas ──
            _QuickStats(
              waitingCount: waiting.length,
              inProgressCount: inProgress.length,
              availableBarbers: availableCount,
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.04, end: 0, duration: 400.ms),

            // ── Sección: Dinámicos (solo clientes que eligieron menor espera) ──
            if (waiting.any((e) => e['is_dynamic'] == true)) ...[
              const SizedBox(height: 24),
              _DynamicQueueSection(
                waitingEntries: waiting
                    .where((e) => e['is_dynamic'] == true)
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
              )
                  .animate(delay: 80.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.03, end: 0, duration: 400.ms),
            ],
            const SizedBox(height: 24),

            // ── Sección: Fila en vivo ──
            Row(
              children: [
                const Text(
                  'Fila en vivo',
                  style: TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
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
                    style: const TextStyle(
                      color: MonacoColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            )
                .animate(delay: 100.ms)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 14),

            // ── Tiles de barberos (flow) ──
            if (staff.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Sin barberos activos',
                    style: TextStyle(color: MonacoColors.textSecondary),
                  ),
                ),
              )
            else
              ...staff.asMap().entries.map((entry) {
                final i = entry.key;
                final s = Map<String, dynamic>.from(entry.value as Map);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BarberFlowTile(
                    name: s['full_name'] ?? 'Barbero',
                    status: s['status'] ?? 'disponible',
                    avatarUrl: s['avatar_url'] as String?,
                    queueAhead: (s['waiting_count'] as int?) ?? 0,
                  )
                      .animate(delay: (150 + i * 60).ms)
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.03, end: 0, duration: 350.ms),
                );
              }),

            const SizedBox(height: 20),

            // ── Sección: Información ──
            const Text(
              'Información',
              style: TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            )
                .animate(delay: 300.ms)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 10),

            // Horario
            _InfoRow(
              icon: Icons.access_time_rounded,
              text:
                  'Horario: ${_formatTime(openTime)} - ${_formatTime(closeTime)}',
            )
                .animate(delay: 350.ms)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 8),

            // Dirección
            if (branchAddress != null)
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: branchAddress,
              )
                  .animate(delay: 400.ms)
                  .fadeIn(duration: 400.ms),

            // Botón "Cómo llegar"
            if (branchLat != null && branchLng != null) ...[
              const SizedBox(height: 16),
              _DirectionsButton(
                latitude: branchLat,
                longitude: branchLng,
              )
                  .animate(delay: 450.ms)
                  .fadeIn(duration: 400.ms),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatTime(String t) {
    final parts = t.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return t;
  }
}

// ── Header: Estado en vivo + ETA ───────────────────────────────────────────

class _LiveHeader extends StatelessWidget {
  final bool isOpen;

  const _LiveHeader({
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // Badge EN VIVO / CERRADO
          _buildLiveBadge(),
          const Spacer(),
          // Sin indicadores de tiempo de espera
        ],
      ),
    );
  }

  Widget _buildLiveBadge() {
    if (!isOpen) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
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
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
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
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats rápidos ──────────────────────────────────────────────────────────

class _QuickStats extends StatelessWidget {
  final int waitingCount;
  final int inProgressCount;
  final int availableBarbers;

  const _QuickStats({
    required this.waitingCount,
    required this.inProgressCount,
    required this.availableBarbers,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatPill(
            value: '$waitingCount',
            label: 'Esperando',
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatPill(
            value: '$inProgressCount',
            label: 'Atendiendo',
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatPill(
            value: '$availableBarbers',
            label: 'Disponibles',
            color: const Color(0xFF22C55E),
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatPill({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
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

// ── Sección: Dinámicos (clientes esperando, sin nombres) ──────────────────

class _DynamicQueueSection extends StatelessWidget {
  final List<Map<String, dynamic>> waitingEntries;

  const _DynamicQueueSection({required this.waitingEntries});

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final created = DateTime.tryParse(createdAt);
    if (created == null) return '';
    final diff = DateTime.now().toUtc().difference(created);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de sección
        Row(
          children: [
            const Text(
              'Dinámicos',
              style: TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${waitingEntries.length}',
                style: const TextStyle(
                  color: amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Lista de clientes en espera (anónimos)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: MonacoColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: amber.withOpacity(0.1)),
          ),
          child: Column(
            children: waitingEntries.asMap().entries.map((entry) {
              final i = entry.key;
              final q = entry.value;
              final staffData = q['staff'] as Map<String, dynamic>?;
              final barberName = staffData?['full_name'] as String?;
              final createdAt = q['created_at'] as String?;
              final isLast = i == waitingEntries.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Círculo con número de posición
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: amber.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: amber.withOpacity(0.3), width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              '#${i + 1}',
                              style: const TextStyle(
                                color: amber,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Tiempo de espera
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Turno ${i + 1}',
                                style: const TextStyle(
                                  color: MonacoColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Esperando hace ${_timeAgo(createdAt)}',
                                style: const TextStyle(
                                  color: MonacoColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Barbero asignado
                        if (barberName != null) ...[
                          Icon(Icons.arrow_forward_rounded,
                              size: 14, color: MonacoColors.textSubtle),
                          const SizedBox(width: 6),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 90),
                            child: Text(
                              barberName.split(' ').first,
                              style: const TextStyle(
                                color: MonacoColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 60,
                      color: Colors.white.withOpacity(0.05),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Info rows ──────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

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
          Icon(icon, size: 16, color: MonacoColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: MonacoColors.textSecondary,
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

class _DirectionsButton extends StatelessWidget {
  final double latitude;
  final double longitude;

  const _DirectionsButton({required this.latitude, required this.longitude});

  Future<void> _openMaps() async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: MonacoColors.gold,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _openMaps,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.directions_rounded, size: 18, color: Colors.black),
                SizedBox(width: 8),
                Text(
                  'Cómo llegar',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
