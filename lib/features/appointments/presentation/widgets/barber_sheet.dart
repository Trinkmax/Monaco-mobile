import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../../data/booking_models.dart';
import '../../data/fechas.dart';

/// Resultado de la hoja: `staffId == null` = "Cualquiera disponible".
/// Si la hoja se cierra sin elegir, `showBarberSheet` devuelve `null`.
class BarberChoice {
  final String? staffId;
  const BarberChoice(this.staffId);
}

/// Hoja inferior "¿Con quién te querés atender?" (réplica de
/// `barber-sheet.tsx`): opción "Cualquiera disponible", un barbero por fila
/// con sus días y franjas REALES, y la sección "Atienden sin turno".
Future<BarberChoice?> showBarberSheet(
  BuildContext context, {
  required List<PublicStaff> staff,
  required List<WalkInStaff> walkIn,
  required String? current,
}) {
  return showLiquidSheet<BarberChoice>(
    context,
    title: '¿Con quién te querés atender?',
    subtitle: 'Elegir barbero puede achicar los horarios que te quedan.',
    builder: (ctx) => _BarberSheetBody(staff: staff, walkIn: walkIn, current: current),
  );
}

class _BarberSheetBody extends StatelessWidget {
  final List<PublicStaff> staff;
  final List<WalkInStaff> walkIn;
  final String? current;

  const _BarberSheetBody({required this.staff, required this.walkIn, required this.current});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Opcion(
          selected: current == null,
          onTap: () => Navigator.of(context).pop(const BarberChoice(null)),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  MonacoColors.seleccion.withValues(alpha: 0.22),
                  MonacoColors.seleccion.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: MonacoColors.seleccion.withValues(alpha: 0.30), width: 0.8),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.white),
          ),
          title: 'Cualquiera disponible',
          badge: 'Sugerido',
          subtitle:
              'Te asignamos al barbero que tenga lugar en el horario que elijas. Es la opción con más horarios.',
        ),
        for (final s in staff) ...[
          const SizedBox(height: 10),
          _Opcion(
            selected: current == s.id,
            onTap: () => Navigator.of(context).pop(BarberChoice(s.id)),
            leading: LiquidAvatar(imageUrl: s.avatarUrl, name: s.fullName, size: 44),
            title: s.fullName,
            subtitle: s.days.isEmpty ? null : 'Toma turnos ${Fechas.textoDias(s.days)}',
            extra: _franjas(s),
          ),
        ],
        if (walkIn.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Text(
            'Atienden sin turno',
            style: TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A estos barberos se los atiende por orden de llegada: no hace falta reservar, acercate y anotate en la tablet.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          for (final w in walkIn) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  LiquidAvatar(imageUrl: w.avatarUrl, name: w.fullName, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.fullName,
                          style: const TextStyle(
                            color: MonacoColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Por orden de llegada',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget? _franjas(PublicStaff s) {
    final dias = s.windows.keys.toList()..sort();
    final filas = <Widget>[];
    for (final d in dias) {
      final rangos = s.windowsFor(d);
      if (rangos.isEmpty) continue;
      filas.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Text(
                Fechas.diasAbrev3[d % 7],
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Text(
                Fechas.textoRangos(rangos),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ));
    }
    if (filas.isEmpty) return null;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DA TURNOS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          ...filas,
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String? badge;
  final String? subtitle;
  final Widget? extra;

  const _Opcion({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    this.badge,
    this.subtitle,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    const accent = MonacoColors.seleccion;
    return LiquidTapEffect(
      onTap: onTap,
      scaleTo: 0.98,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [accent.withValues(alpha: 0.22), accent.withValues(alpha: 0.07)]
                : [Colors.white.withValues(alpha: 0.09), Colors.white.withValues(alpha: 0.03)],
          ),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.14),
            width: selected ? 1.1 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MonacoColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: accent.withValues(alpha: 0.18),
                                border: Border.all(color: accent.withValues(alpha: 0.45), width: 0.8),
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  color: accent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                  color: selected ? accent : Colors.white.withValues(alpha: 0.3),
                  size: 22,
                ),
              ],
            ),
            ?extra,
          ],
        ),
      ),
    );
  }
}
