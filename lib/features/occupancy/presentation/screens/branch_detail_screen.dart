import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';

class BranchDetailScreen extends ConsumerWidget {
  final String branchId;
  const BranchDetailScreen({super.key, required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(branchDetailProvider(branchId));

    ref.listen(branchQueueRealtimeProvider(branchId), (_, _) {
      ref.invalidate(branchDetailProvider(branchId));
    });
    ref.listen(branchAttendanceRealtimeProvider(branchId), (_, _) {
      ref.invalidate(branchDetailProvider(branchId));
    });

    final title = detail.maybeWhen(
      data: (d) => d['branch']?['name'] as String? ?? 'Sucursal',
      orElse: () => 'Sucursal',
    );

    return LiquidAppBarScaffold(
      title: title,
      showBackButton: true,
      body: detail.when(
        data: (data) => _LiveQueueContent(data: data),
        loading: () => _buildShimmer(),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(branchDetailProvider(branchId)),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
      child: Column(
        children: [
          _ShimmerBlock(height: 180),
          const SizedBox(height: 14),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                  child: _ShimmerBlock(height: 78),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ShimmerBlock(height: 80),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: MonacoColors.destructive),
          const SizedBox(height: 12),
          Text(
            'Error al cargar detalle',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 16),
          LiquidPill(
            onTap: onRetry,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: const Text(
              'Reintentar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  final double height;
  const _ShimmerBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white10);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONTENIDO PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════

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

    final occupancy = _computeOccupancy(
      isOpen: isOpen,
      availableCount: availableCount,
      waitingCount: waiting.length,
      activeBarbers: totalBarbers,
    );

    final availableBarbers = staff
        .where((s) => (s as Map)['status'] == 'disponible')
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: MonacoColors.surface,
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OccupancyHero(
              occupancy: occupancy,
              activeBarbers: totalBarbers,
            ).liquidEnter(index: 0),

            const SizedBox(height: 14),

            _QuickStats(
              waitingCount: waiting.length,
              inProgressCount: inProgress.length,
              availableBarbers: availableCount,
            ).liquidEnter(index: 1),

            if (availableBarbers.isNotEmpty) ...[
              const SizedBox(height: 20),
              _AvailableBarbersStrip(barbers: availableBarbers)
                  .liquidEnter(index: 2),
            ],

            if (inProgress.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionHeader(
                icon: Icons.content_cut_rounded,
                title: 'En atención',
                count: inProgress.length,
                accent: LiquidTokens.monacoGreen,
              ).liquidEnter(index: 3),
              const SizedBox(height: 12),
              ...inProgress.asMap().entries.map((entry) {
                final i = entry.key;
                final e = Map<String, dynamic>.from(entry.value as Map);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child:
                      _InProgressCard(entry: e).liquidEnter(index: 4 + i),
                );
              }),
            ],

            if (waiting.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionHeader(
                icon: Icons.schedule_rounded,
                title: 'Próximos turnos',
                count: waiting.length,
                accent: const Color(0xFF3B82F6),
              ).liquidEnter(index: 5 + inProgress.length),
              const SizedBox(height: 12),
              _WaitingList(
                waitingEntries: waiting
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
              ).liquidEnter(index: 6 + inProgress.length),
            ],

            if (inProgress.isEmpty &&
                waiting.isEmpty &&
                occupancy.level != _OccupancyLevel.closed) ...[
              const SizedBox(height: 24),
              _EmptyState(totalBarbers: totalBarbers).liquidEnter(index: 4),
            ],

            const SizedBox(height: 28),
            _SectionHeader(
              icon: Icons.info_outline_rounded,
              title: 'Información',
              accent: Colors.white.withOpacity(0.7),
            ).liquidEnter(index: 10),
            const SizedBox(height: 12),

            _InfoRow(
              icon: Icons.access_time_rounded,
              text:
                  'Horario: ${_formatTime(openTime)} - ${_formatTime(closeTime)}',
            ).liquidEnter(index: 11),
            const SizedBox(height: 8),

            if (branchAddress != null)
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: branchAddress,
              ).liquidEnter(index: 12),

            if (branchLat != null && branchLng != null) ...[
              const SizedBox(height: 18),
              _DirectionsButton(latitude: branchLat, longitude: branchLng)
                  .liquidEnter(index: 13),
            ],
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

// ═══════════════════════════════════════════════════════════════════════════
// LÓGICA DE OCUPACIÓN (optimista)
// ═══════════════════════════════════════════════════════════════════════════

enum _OccupancyLevel { closed, free, low, medium, high }

class _OccupancyInfo {
  final _OccupancyLevel level;
  final Color color;
  final String title;
  final String subtitle;
  final double fillRatio;

  const _OccupancyInfo({
    required this.level,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.fillRatio,
  });
}

_OccupancyInfo _computeOccupancy({
  required bool isOpen,
  required int availableCount,
  required int waitingCount,
  required int activeBarbers,
}) {
  if (!isOpen || activeBarbers == 0) {
    return const _OccupancyInfo(
      level: _OccupancyLevel.closed,
      color: Color(0xFF6B6B6B),
      title: 'Cerrado',
      subtitle: 'Volvemos pronto',
      fillRatio: 0.0,
    );
  }

  if (availableCount >= 1) {
    return const _OccupancyInfo(
      level: _OccupancyLevel.free,
      color: LiquidTokens.monacoGreen,
      title: 'Libre ahora',
      subtitle: 'Entrá cuando quieras, sin espera',
      fillRatio: 0.15,
    );
  }

  final ratio = waitingCount / activeBarbers;

  if (ratio < 1.5) {
    return const _OccupancyInfo(
      level: _OccupancyLevel.low,
      color: Color(0xFF84CC16),
      title: 'Espera corta',
      subtitle: 'Aprox. un turno por barbero',
      fillRatio: 0.45,
    );
  }

  if (ratio < 2.5) {
    return const _OccupancyInfo(
      level: _OccupancyLevel.medium,
      color: Color(0xFFF59E0B),
      title: 'Movimiento moderado',
      subtitle: 'Aprox. dos turnos por barbero',
      fillRatio: 0.75,
    );
  }

  return const _OccupancyInfo(
    level: _OccupancyLevel.high,
    color: Color(0xFFEF4444),
    title: 'Mayor demanda',
    subtitle: 'Varios turnos por barbero',
    fillRatio: 1.0,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO DE OCUPACIÓN — glass tintado con el color del nivel
// ═══════════════════════════════════════════════════════════════════════════

class _OccupancyHero extends StatelessWidget {
  final _OccupancyInfo occupancy;
  final int activeBarbers;

  const _OccupancyHero({
    required this.occupancy,
    required this.activeBarbers,
  });

  @override
  Widget build(BuildContext context) {
    final isClosed = occupancy.level == _OccupancyLevel.closed;
    final color = occupancy.color;

    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      borderRadius: 26,
      tint: color,
      tintOpacity: 0.12,
      pressable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LiquidStatusPill(
                label: isClosed ? 'CERRADO' : 'EN VIVO',
                color: isClosed ? Colors.grey : LiquidTokens.monacoGreen,
                pulse: !isClosed,
                compact: true,
              ),
              const Spacer(),
              if (!isClosed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.group_rounded,
                      size: 14,
                      color: Colors.white.withOpacity(0.65),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$activeBarbers ${activeBarbers == 1 ? "barbero activo" : "barberos activos"}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),

          Text(
            occupancy.title,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.0,
              shadows: [
                Shadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            occupancy.subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),

          _buildOccupancyBar(color),
        ],
      ),
    );
  }

  Widget _buildOccupancyBar(Color color) {
    final segments = [0.25, 0.5, 0.75, 1.0];
    return Row(
      children: List.generate(segments.length, (i) {
        final threshold = segments[i];
        final filled = occupancy.fillRatio >= threshold - 0.05;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < segments.length - 1 ? 5 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 7,
              decoration: BoxDecoration(
                color: filled
                    ? color.withOpacity(0.9)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4),
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// QUICK STATS
// ═══════════════════════════════════════════════════════════════════════════

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
            icon: Icons.hourglass_top_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatPill(
            value: '$inProgressCount',
            label: 'Atendiendo',
            icon: Icons.content_cut_rounded,
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatPill(
            value: '$availableBarbers',
            label: 'Libres',
            icon: Icons.check_circle_outline_rounded,
            color: LiquidTokens.monacoGreen,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatPill({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      borderRadius: 18,
      tint: color,
      tintOpacity: 0.08,
      pressable: false,
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: [
                Shadow(
                  color: color.withOpacity(0.45),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
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

// ═══════════════════════════════════════════════════════════════════════════
// BARBEROS DISPONIBLES — chips horizontales glass
// ═══════════════════════════════════════════════════════════════════════════

class _AvailableBarbersStrip extends StatelessWidget {
  final List<Map<String, dynamic>> barbers;

  const _AvailableBarbersStrip({required this.barbers});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: LiquidTokens.monacoGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: LiquidTokens.monacoGreen.withOpacity(0.7),
                    blurRadius: 6,
                  ),
                ],
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.6, duration: 900.ms),
            const SizedBox(width: 8),
            Text(
              'Libres ahora',
              style: TextStyle(
                color: LiquidTokens.monacoGreen.withOpacity(0.95),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: barbers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final b = barbers[i];
              final name = b['full_name'] as String? ?? 'Barbero';
              final avatarUrl = b['avatar_url'] as String?;
              final firstName = name.split(' ').first;
              return _AvailableBarberChip(
                name: firstName,
                avatarUrl: avatarUrl,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AvailableBarberChip extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _AvailableBarberChip({required this.name, this.avatarUrl});

  String get _initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    const green = LiquidTokens.monacoGreen;
    return LiquidPill(
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
      tint: green,
      tintOpacity: 0.10,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: MonacoColors.surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(color: green, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: green.withOpacity(0.35),
                  blurRadius: 8,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                ? Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _InitialFallback(text: _initial),
                  )
                : _InitialFallback(text: _initial),
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: const TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialFallback extends StatelessWidget {
  final String text;
  const _InitialFallback({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          color: LiquidTokens.monacoGreen,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int? count;
  final Color accent;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.count,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withOpacity(0.22),
                accent.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: accent.withOpacity(0.28), width: 0.8),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withOpacity(0.22), width: 0.6),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EN ATENCIÓN — glass card
// ═══════════════════════════════════════════════════════════════════════════

class _InProgressCard extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _InProgressCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    const green = LiquidTokens.monacoGreen;
    final staffData = entry['staff'] as Map<String, dynamic>?;
    final barberName = staffData?['full_name'] as String? ?? 'Barbero';
    final avatarUrl = staffData?['avatar_url'] as String?;

    return LiquidGlass(
      padding: const EdgeInsets.all(12),
      borderRadius: 18,
      tintOpacity: 0.07,
      pressable: false,
      showVignette: false,
      child: Row(
        children: [
          _Avatar(
            name: barberName,
            avatarUrl: avatarUrl,
            ringColor: Colors.white.withOpacity(0.2),
            size: 54,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  barberName,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Atendiendo ahora',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  green.withOpacity(0.25),
                  green.withOpacity(0.10),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: green.withOpacity(0.4), width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: green.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Icon(
              Icons.content_cut_rounded,
              size: 16,
              color: green,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRÓXIMOS TURNOS — bloque glass con filas tipo section card
// ═══════════════════════════════════════════════════════════════════════════

class _WaitingList extends StatelessWidget {
  final List<Map<String, dynamic>> waitingEntries;

  const _WaitingList({required this.waitingEntries});

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
    final rows = <Widget>[];
    for (var i = 0; i < waitingEntries.length; i++) {
      final q = waitingEntries[i];
      final staffData = q['staff'] as Map<String, dynamic>?;
      final barberName = staffData?['full_name'] as String?;
      final isDynamic = q['is_dynamic'] == true;
      final createdAt = q['created_at'] as String?;
      rows.add(
        _WaitingTile(
          position: i + 1,
          barberName: barberName,
          isDynamic: isDynamic,
          waitingFor: _timeAgo(createdAt),
          isFirst: i == 0,
        ),
      );
    }

    return LiquidSectionCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: rows,
    );
  }
}

class _WaitingTile extends StatelessWidget {
  final int position;
  final String? barberName;
  final bool isDynamic;
  final String waitingFor;
  final bool isFirst;

  const _WaitingTile({
    required this.position,
    required this.barberName,
    required this.isDynamic,
    required this.waitingFor,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF3B82F6);
    const amber = Color(0xFFF59E0B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: isFirst
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFFFFF), Color(0xFFDDDDDD)],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.04),
                      ],
                    ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFirst
                    ? Colors.white
                    : Colors.white.withOpacity(0.12),
                width: 0.8,
              ),
              boxShadow: isFirst
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.25),
                        blurRadius: 14,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '$position',
                style: TextStyle(
                  color: isFirst
                      ? Colors.black
                      : Colors.white.withOpacity(0.65),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFirst ? 'Próximo en ser llamado' : 'Turno $position',
                  style: TextStyle(
                    color: isFirst
                        ? Colors.white
                        : Colors.white.withOpacity(0.88),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (isDynamic && barberName != null) ...[
                      Icon(Icons.bolt_rounded, size: 13, color: amber),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Menor espera · ${barberName!.split(' ').first}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else if (barberName != null) ...[
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 12,
                        color: Colors.white.withOpacity(0.4),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Con ${barberName!.split(' ').first}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      Icon(Icons.bolt_rounded, size: 13, color: amber),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Menor espera',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (waitingFor.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    blue.withOpacity(0.18),
                    blue.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: blue.withOpacity(0.28), width: 0.6),
              ),
              child: Text(
                waitingFor,
                style: TextStyle(
                  color: blue.withOpacity(0.92),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ESTADO VACÍO (la sala está libre)
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final int totalBarbers;

  const _EmptyState({required this.totalBarbers});

  @override
  Widget build(BuildContext context) {
    const green = LiquidTokens.monacoGreen;
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      borderRadius: 20,
      tint: green,
      tintOpacity: 0.06,
      pressable: false,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  green.withOpacity(0.30),
                  green.withOpacity(0.14),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: green.withOpacity(0.38)),
              boxShadow: [
                BoxShadow(
                  color: green.withOpacity(0.32),
                  blurRadius: 18,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 28,
              color: green,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'La sala está libre',
            style: TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            totalBarbers == 1
                ? 'Hay 1 barbero esperando para atenderte'
                : 'Hay $totalBarbers barberos esperando para atenderte',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AVATAR
// ═══════════════════════════════════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final Color ringColor;
  final double size;

  const _Avatar({
    required this.name,
    required this.avatarUrl,
    required this.ringColor,
    required this.size,
  });

  String get _initial {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      inner = ClipOval(
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    } else {
      inner = _fallback();
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 1.5),
      ),
      child: SizedBox(width: size, height: size, child: inner),
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ringColor.withOpacity(0.28),
            ringColor.withOpacity(0.08),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _initial,
          style: TextStyle(
            color: ringColor,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.35,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INFO ROWS + DIRECCIONES
// ═══════════════════════════════════════════════════════════════════════════

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 14,
      pressable: false,
      showVignette: false,
      tintOpacity: 0.05,
      blur: LiquidTokens.blurSubtle,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.65)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
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

  const _DirectionsButton({
    required this.latitude,
    required this.longitude,
  });

  Future<void> _openMaps() async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return LiquidButton(
      onPressed: _openMaps,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.directions_rounded, size: 18, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Cómo llegar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
