import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/appointments/data/appointment_model.dart';
import 'package:monaco_mobile/features/appointments/presentation/widgets/appointment_countdown.dart';

/// La fila de turnos del Home.
///
/// **Con turno**: dos tiles — reservar otro y el próximo, con hora grande y
/// countdown vivo.
/// **Sin turno**: un solo CTA ancho. Un tile "Próximo turno · —" ocuparía media
/// pantalla para decir que no hay nada; el ancho, en cambio, empuja a la acción
/// que sí queremos.
class TurnoTiles extends StatelessWidget {
  final Appointment? proximo;
  final bool cargando;

  /// ¿Alguna sucursal toma turnos online? Si no, no se ofrece reservar.
  final bool reservable;

  const TurnoTiles({
    super.key,
    required this.proximo,
    required this.cargando,
    required this.reservable,
  });

  /// 152 y no 138: el tile del próximo turno apila ícono + hora grande +
  /// "Jue 27 · Paraná" + countdown, que suman 139 con los paddings.
  static const double _alto = 152;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const LiquidSkeleton(height: _alto, radius: 24);
    }

    final a = proximo;
    if (a == null) {
      if (!reservable) return const SizedBox.shrink();
      return const _CtaAncho();
    }

    return SizedBox(
      height: _alto,
      child: Row(
        children: [
          if (reservable) ...[
            const Expanded(child: _TileReservar()),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: reservable ? 1 : 2,
            child: _TileProximoTurno(appointment: a),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0, duration: 400.ms);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TILE — RESERVAR
// ═══════════════════════════════════════════════════════════════════════════

class _TileReservar extends StatelessWidget {
  const _TileReservar();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Reservar turno',
      child: LiquidGlass(
        onTap: () => context.push('/turnos/reservar'),
        padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
        borderRadius: 24,
        tint: MonacoColors.monacoGreen,
        tintOpacity: 0.13,
        showVignette: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _IconoTile(
              icono: Icons.calendar_month_rounded,
              accent: MonacoColors.monacoGreen,
            ),
            const Spacer(),
            const Text(
              'Reservar\nturno',
              maxLines: 2,
              style: TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Te lleva un minuto',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TILE — PRÓXIMO TURNO
// ═══════════════════════════════════════════════════════════════════════════

class _TileProximoTurno extends StatelessWidget {
  final Appointment appointment;
  const _TileProximoTurno({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final enElLocal = a.status.isAtShop;
    final accent = enElLocal ? MonacoColors.info : Colors.white;
    // `etiquetaDia()` devuelve "Jueves, 27 de agosto": en un tile de media
    // pantalla se corta antes de llegar a la sucursal, que es el dato que
    // desempata cuando el cliente tiene turnos en dos locales. La forma corta
    // ("Jue 27") entra con la sucursal al lado.
    final dia = a.etiquetaDia();
    final diaCorto = (dia == 'Hoy' || dia == 'Mañana') ? dia : a.fechaCorta;
    final detalle = [
      diaCorto,
      if ((a.branchName ?? '').trim().isNotEmpty) a.branchName!.trim(),
    ].join(' · ');
    final faltaPoco = enElLocal ||
        a.startInstant.difference(DateTime.now().toUtc()).inHours < 24;

    return Semantics(
      button: true,
      label: 'Tu próximo turno, ${a.horaLabel}, ${a.etiquetaDia()}. Ver detalle',
      child: LiquidGlass(
        onTap: () => context.push('/turnos/${a.id}'),
        padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
        borderRadius: 24,
        tint: enElLocal ? MonacoColors.info : null,
        tintOpacity: enElLocal ? 0.14 : 0.08,
        showVignette: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // El countdown va como línea de texto abajo, NO como pastilla
            // arriba: al lado del ícono le quedaban ~60 px y se renderizaba
            // como un reloj sin texto (verificado en el simulador).
            _IconoTile(
              icono: enElLocal
                  ? Icons.storefront_rounded
                  : Icons.content_cut_rounded,
              accent: accent,
            ),
            const Spacer(),
            Text(
              enElLocal ? a.status.label : a.horaLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: enElLocal ? 19 : 29,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: -1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detalle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            // El countdown SÓLO cuando dice algo nuevo. A más de 24 h,
            // `cuentaRegresiva` devuelve "Jue 27 ago · 18:30", que es
            // exactamente la línea de arriba más la hora que ya está en 29 px:
            // el tile terminaba repitiéndose tres veces.
            if (faltaPoco) ...[
              const SizedBox(height: 3),
              AppointmentCountdown(
                appointment: a,
                style: TextStyle(
                  color: (enElLocal ? MonacoColors.info : MonacoColors.monacoGreen)
                      .withValues(alpha: 0.95),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconoTile extends StatelessWidget {
  final IconData icono;
  final Color accent;
  const _IconoTile({required this.icono, required this.accent});

  @override
  Widget build(BuildContext context) {
    final tinte = accent != Colors.white;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: tinte ? 0.32 : 0.18),
            accent.withValues(alpha: tinte ? 0.12 : 0.06),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: tinte ? 0.45 : 0.22),
          width: 0.8,
        ),
        boxShadow: tinte
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 12,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Icon(icono, color: Colors.white, size: 19),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CTA ANCHO — cuando no hay ningún turno
// ═══════════════════════════════════════════════════════════════════════════

class _CtaAncho extends StatelessWidget {
  const _CtaAncho();

  @override
  Widget build(BuildContext context) {
    const accent = MonacoColors.monacoGreen;
    return Semantics(
      button: true,
      label: 'Reservá tu turno',
      child: LiquidGlass(
        onTap: () => context.push('/turnos/reservar'),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        borderRadius: 24,
        tint: accent,
        tintOpacity: 0.13,
        showVignette: false,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.34),
                    accent.withValues(alpha: 0.12),
                  ],
                ),
                border: Border.all(color: accent.withValues(alpha: 0.45), width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 14,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reservá tu turno',
                    style: TextStyle(
                      color: MonacoColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Elegís sucursal, servicio y horario. Sin esperar en el local.',
                    style: TextStyle(
                      color: Color(0xA6FFFFFF),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.9),
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 12),
                ],
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  size: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0, duration: 400.ms);
  }
}
