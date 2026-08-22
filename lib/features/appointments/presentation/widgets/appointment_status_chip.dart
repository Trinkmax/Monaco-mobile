import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../../data/appointment_model.dart';

/// Chip de estado de un turno con el lenguaje [LiquidStatusPill].
class AppointmentStatusChip extends StatelessWidget {
  final AppointmentStatus status;
  final bool compact;

  const AppointmentStatusChip({
    super.key,
    required this.status,
    this.compact = true,
  });

  static Color colorFor(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.scheduled:
      case AppointmentStatus.confirmed:
        return MonacoColors.monacoGreen;
      case AppointmentStatus.pendingPayment:
        return MonacoColors.warning;
      case AppointmentStatus.checkedIn:
        return MonacoColors.info;
      case AppointmentStatus.inProgress:
        return MonacoColors.warning;
      case AppointmentStatus.completed:
        return MonacoColors.foregroundMuted;
      case AppointmentStatus.cancelled:
      case AppointmentStatus.noShow:
        return MonacoColors.destructive;
      case AppointmentStatus.unknown:
        return MonacoColors.foregroundSubtle;
    }
  }

  static bool pulseFor(AppointmentStatus s) =>
      s == AppointmentStatus.checkedIn || s == AppointmentStatus.inProgress;

  @override
  Widget build(BuildContext context) {
    return LiquidStatusPill(
      label: status.label.toUpperCase(),
      color: colorFor(status),
      pulse: pulseFor(status),
      compact: compact,
    );
  }
}
