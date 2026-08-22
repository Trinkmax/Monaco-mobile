import 'dart:async';

import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';

import '../../data/appointment_model.dart';
import '../../data/fechas.dart';

/// Cuenta regresiva viva ("en 2 h 15 min", "Mañana 15:00", "Es ahora").
/// Se recalcula sola cada 30 s, para que la tarjeta no quede vieja si la
/// pantalla queda abierta.
class AppointmentCountdown extends StatefulWidget {
  final Appointment appointment;
  final TextStyle? style;
  final bool pill;

  const AppointmentCountdown({
    super.key,
    required this.appointment,
    this.style,
    this.pill = false,
  });

  /// Texto (sin widget) para usar en semánticas o tests.
  static String textFor(Appointment a, {DateTime? now}) {
    if (a.status == AppointmentStatus.inProgress) return 'En atención ahora';
    if (a.status == AppointmentStatus.checkedIn) return 'Ya llegaste · te llaman en breve';
    return Fechas.cuentaRegresiva(
      start: a.startInstant,
      end: a.endInstant,
      dateStr: a.dateStr,
      hhmmStr: a.startTime,
      tz: a.branchTimezone,
      now: now,
    );
  }

  @override
  State<AppointmentCountdown> createState() => _AppointmentCountdownState();
}

class _AppointmentCountdownState extends State<AppointmentCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final text = AppointmentCountdown.textFor(a);
    final live = a.status.isAtShop ||
        a.startInstant.difference(DateTime.now().toUtc()).inHours < 24;
    final accent = a.status.isAtShop
        ? MonacoColors.info
        : (live ? MonacoColors.monacoGreen : Colors.white);

    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style ??
          TextStyle(
            color: widget.pill ? accent : Colors.white.withValues(alpha: 0.85),
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );

    if (!widget.pill) return label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.24),
            accent.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 13, color: accent),
          const SizedBox(width: 5),
          Flexible(child: label),
        ],
      ),
    );
  }
}
