import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';

/// Tile visual estilo "flow/pipeline" para cada barbero.
/// Muestra avatar con anillo de estado, nombre, badge de estado,
/// y una pipeline visual de la cola (sin nombres de clientes).
class BarberFlowTile extends StatelessWidget {
  final String name;
  final String status; // disponible | ocupado | descanso
  final String? avatarUrl;
  final int queueAhead;

  const BarberFlowTile({
    super.key,
    required this.name,
    required this.status,
    this.avatarUrl,
    this.queueAhead = 0,
  });

  Color get _statusColor {
    switch (status) {
      case 'ocupado':
        return const Color(0xFFF59E0B);
      case 'descanso':
        return Colors.grey;
      case 'disponible':
      default:
        return const Color(0xFF22C55E);
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'ocupado':
        return 'Atendiendo';
      case 'descanso':
        return 'Descanso';
      case 'disponible':
      default:
        return 'Disponible';
    }
  }

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
    final color = _statusColor;
    final bool hasQueue = status == 'ocupado' || queueAhead > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Fila superior: Avatar + Nombre + Badge ──
          Row(
            children: [
              _buildAvatar(color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: MonacoColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (status == 'disponible' && queueAhead == 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text(
                          'Libre ahora',
                          style: TextStyle(
                            color: Color(0xFF22C55E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (status == 'descanso')
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'Vuelve pronto',
                          style: TextStyle(
                            color: MonacoColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildStatusBadge(color),
            ],
          ),

          // ── Pipeline visual de la cola ──
          if (hasQueue) ...[
            const SizedBox(height: 14),
            _buildQueuePipeline(color),
          ],

          // ETA removido
        ],
      ),
    );
  }

  // ── Avatar con anillo de estado ──────────────────────────────────────────

  Widget _buildAvatar(Color color) {
    Widget avatar;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: MonacoColors.surface,
        onBackgroundImageError: (_, __) {},
      );
    } else {
      avatar = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.20),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Center(
          child: Text(
            _initial,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: avatar,
    );
  }

  // ── Badge de estado con punto animado ────────────────────────────────────

  Widget _buildStatusBadge(Color color) {
    final bool hasGlow = status != 'descanso';

    Widget dot = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: hasGlow
            ? [
                BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1),
              ]
            : null,
      ),
    );

    if (hasGlow) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1.0, end: 1.35, duration: 900.ms);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 6),
          Text(
            _statusLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Pipeline visual: ✂️ ── ● ── ● ── ● ────────────────────────────────

  Widget _buildQueuePipeline(Color color) {
    final displayCount = min(queueAhead, 6);
    final hasOverflow = queueAhead > 6;
    final bool isServing = status == 'ocupado';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MonacoColors.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Punto activo: cliente en atención
            if (isServing) ...[
              _buildActiveDot(color),
              if (queueAhead > 0) _buildConnector(color),
            ],
            // Puntos de espera numerados
            for (int i = 0; i < displayCount; i++) ...[
              _buildWaitingDot(i + 1, color),
              if (i < displayCount - 1 || hasOverflow) _buildConnector(color),
            ],
            // Indicador de overflow
            if (hasOverflow)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${queueAhead - 6}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            // Sin cola para barberos disponibles que tienen waiting asignados
            if (!isServing && queueAhead > 0)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  'en espera',
                  style: TextStyle(
                    color: MonacoColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDot(Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 10,
              spreadRadius: 1),
        ],
      ),
      child: Icon(Icons.content_cut_rounded, size: 16, color: color),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1.0, end: 1.06, duration: 1200.ms);
  }

  Widget _buildWaitingDot(int number, Color color) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: color.withOpacity(0.75),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildConnector(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
