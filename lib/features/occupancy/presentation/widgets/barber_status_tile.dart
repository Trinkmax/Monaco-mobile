import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';

class BarberStatusTile extends StatelessWidget {
  final String name;
  final String status; // disponible | ocupado | descanso
  final String? avatarUrl;
  final String? currentClientName;
  final int? etaMinutes;
  final int queueAhead; // cortes en espera después del cliente actual

  const BarberStatusTile({
    super.key,
    required this.name,
    required this.status,
    this.avatarUrl,
    this.currentClientName,
    this.etaMinutes,
    this.queueAhead = 0,
  });

  Color get _statusColor {
    switch (status) {
      case 'ocupado':
        return const Color(0xFFF59E0B); // ámbar
      case 'descanso':
        return Colors.grey;
      case 'disponible':
      default:
        return const Color(0xFF22C55E); // verde
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'ocupado':
        return 'Ocupado';
      case 'descanso':
        return 'En descanso';
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
    final accentColor = _statusColor;

    return Stack(
      children: [
        // Tarjeta base con borde completo tenue
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.fromLTRB(17, 14, 14, 14),
            decoration: BoxDecoration(
              color: MonacoColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accentColor.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                _buildAvatar(),
                const SizedBox(width: 14),

                // Nombre + subtítulo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: MonacoColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildSubtitle(),
                    ],
                  ),
                ),

                // Badge de estado
                _buildStatusBadge(accentColor),
              ],
            ),
          ),
        ),

        // Acento izquierdo coloreado (borde lateral de 3px)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 3,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScissorsIndicator() {
    if (queueAhead == 0) return const SizedBox.shrink();

    final color = _statusColor; // ámbar para ocupado
    final displayCount = queueAhead.clamp(1, 5);
    final hasMore = queueAhead > 5;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          ...List.generate(displayCount, (i) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.content_cut_rounded,
              size: 13,
              color: color,
            ),
          )),
          if (hasMore)
            Text(
              '+${queueAhead - 5}',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    if (status == 'ocupado') {
      final subtitleText = (currentClientName != null && currentClientName!.isNotEmpty)
          ? 'Atendiendo a $currentClientName'
          : 'Ocupado';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            subtitleText,
            style: TextStyle(
              color: MonacoColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          _buildScissorsIndicator(),
        ],
      );
    }

    if (status == 'disponible') {
      return Text(
        'Libre ahora',
        style: const TextStyle(
          color: Color(0xFF22C55E),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // descanso
    return Text(
      'En descanso',
      style: TextStyle(
        color: MonacoColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildStatusBadge(Color color) {
    // El punto interior tiene glow en disponible y ocupado, estático en descanso
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
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );

    // Pulso animado solo cuando hay glow
    if (hasGlow) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1.0, end: 1.35, duration: 900.ms);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
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

  Widget _buildAvatar() {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: MonacoColors.surface,
        onBackgroundImageError: (_, __) {},
      );
    }

    // Avatar con gradiente sutil basado en el color de estado
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _statusColor.withOpacity(0.20),
            _statusColor.withOpacity(0.05),
          ],
        ),
        border: Border.all(color: _statusColor.withOpacity(0.25)),
      ),
      child: Center(
        child: Text(
          _initial,
          style: TextStyle(
            color: _statusColor,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
