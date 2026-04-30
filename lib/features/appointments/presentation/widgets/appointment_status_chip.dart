import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../../data/appointment_model.dart';

/// Chip de estado de un turno usando el lenguaje [LiquidStatusPill].
class AppointmentStatusChip extends StatelessWidget {
  final AppointmentStatus status;
  final bool compact;

  const AppointmentStatusChip({
    super.key,
    required this.status,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(status);
    return LiquidStatusPill(
      label: status.label.toUpperCase(),
      color: palette.color,
      pulse: palette.pulse,
      compact: compact,
    );
  }

  _StatusPalette _paletteFor(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.scheduled:
      case AppointmentStatus.confirmed:
        return const _StatusPalette(Color(0xFF22C55E), pulse: false);
      case AppointmentStatus.checkedIn:
        return const _StatusPalette(Color(0xFF0091FF), pulse: true);
      case AppointmentStatus.inProgress:
        return const _StatusPalette(Color(0xFFF5A623), pulse: true);
      case AppointmentStatus.completed:
        return const _StatusPalette(Color(0xFFA3A3A3), pulse: false);
      case AppointmentStatus.cancelled:
        return const _StatusPalette(Color(0xFFE5484D), pulse: false);
      case AppointmentStatus.noShow:
        return const _StatusPalette(Color(0xFFE5484D), pulse: false);
      case AppointmentStatus.unknown:
        return const _StatusPalette(Color(0xFF6B6B6B), pulse: false);
    }
  }
}

class _StatusPalette {
  final Color color;
  final bool pulse;
  const _StatusPalette(this.color, {this.pulse = false});
}
