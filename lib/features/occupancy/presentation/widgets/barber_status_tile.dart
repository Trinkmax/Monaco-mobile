import 'package:flutter/material.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';

class BarberStatusTile extends StatelessWidget {
  final String name;
  final String status; // disponible | ocupado | descanso
  final String? currentClientName;

  const BarberStatusTile({
    super.key,
    required this.name,
    required this.status,
    this.currentClientName,
  });

  Color get _statusColor {
    switch (status) {
      case 'ocupado':
        return const Color(0xFFF59E0B); // amber
      case 'descanso':
        return Colors.grey;
      case 'disponible':
      default:
        return const Color(0xFF22C55E); // green
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MonacoColors.divider.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: _statusColor.withOpacity(0.15),
            child: Text(
              _initial,
              style: TextStyle(
                color: _statusColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + status
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
                if (status == 'ocupado' &&
                    currentClientName != null &&
                    currentClientName!.isNotEmpty)
                  Text(
                    'Atendiendo a $currentClientName',
                    style: TextStyle(
                      color: MonacoColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Status badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                    boxShadow: status == 'disponible'
                        ? [
                            BoxShadow(
                              color: _statusColor.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
