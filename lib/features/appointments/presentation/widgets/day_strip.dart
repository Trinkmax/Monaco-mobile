import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../../data/fechas.dart';

/// Tira horizontal de días (réplica de `day-strip.tsx`): abreviatura, número
/// y una tercera línea con "Hoy" / "Mañana" / "Lleno" / reintentar.
///
/// - Deshabilitado (no toma turnos ese día): opaco al 0.34, no responde.
/// - "Lleno": opaco al 0.62 pero SIGUE tocable.
/// - Sin datos: ícono de reintentar; tocarlo vuelve a consultar.
class DayStrip extends StatefulWidget {
  final List<String> days;
  final String today;
  final List<int> enabledDays;
  final String? selected;
  final Set<String> fullDates;
  final Set<String> unknownDates;
  final ValueChanged<String> onSelect;

  const DayStrip({
    super.key,
    required this.days,
    required this.today,
    required this.enabledDays,
    required this.selected,
    required this.fullDates,
    required this.unknownDates,
    required this.onSelect,
  });

  @override
  State<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<DayStrip> {
  static const _chipW = 62.0;
  static const _gap = 8.0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected(animated: false));
  }

  @override
  void didUpdateWidget(covariant DayStrip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected(animated: true));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToSelected({required bool animated}) {
    if (!_scroll.hasClients || widget.selected == null) return;
    final idx = widget.days.indexOf(widget.selected!);
    if (idx < 0) return;
    final viewport = _scroll.position.viewportDimension;
    final target = (idx * (_chipW + _gap) - (viewport - _chipW) / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    if (animated) {
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manana = Fechas.addDays(widget.today, 1);
    return SizedBox(
      height: 88,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        clipBehavior: Clip.none,
        itemCount: widget.days.length,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: (context, i) {
          final d = widget.days[i];
          final dow = Fechas.dayOfWeek(d);
          final enabled = widget.enabledDays.contains(dow);
          final lleno = widget.fullDates.contains(d);
          final sinDatos = widget.unknownDates.contains(d);
          String? tercera;
          if (d == widget.today) {
            tercera = 'Hoy';
          } else if (d == manana) {
            tercera = 'Mañana';
          } else if (lleno) {
            tercera = 'Lleno';
          }
          return _DayChip(
            abrev: Fechas.diasAbrevMayus[dow],
            numero: Fechas.parseDate(d).day.toString(),
            tercera: tercera,
            lleno: lleno,
            sinDatos: sinDatos,
            enabled: enabled,
            selected: widget.selected == d,
            onTap: enabled ? () => widget.onSelect(d) : null,
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String abrev;
  final String numero;
  final String? tercera;
  final bool lleno;
  final bool sinDatos;
  final bool enabled;
  final bool selected;
  final VoidCallback? onTap;

  const _DayChip({
    required this.abrev,
    required this.numero,
    required this.tercera,
    required this.lleno,
    required this.sinDatos,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = MonacoColors.monacoGreen;
    final opacity = !enabled ? 0.34 : (lleno && !selected ? 0.62 : 1.0);

    final box = AnimatedContainer(
      duration: LiquidTokens.swap,
      curve: LiquidTokens.curveSwap,
      width: 62,
      height: 84,
      transform: Matrix4.diagonal3Values(selected ? 1.04 : 1.0, selected ? 1.04 : 1.0, 1),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [accent.withValues(alpha: 0.55), accent.withValues(alpha: 0.28)]
              : [Colors.white.withValues(alpha: 0.09), Colors.white.withValues(alpha: 0.035)],
        ),
        border: Border.all(
          color: selected ? accent.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.16),
          width: selected ? 1.1 : 0.8,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            abrev,
            style: TextStyle(
              color: Colors.white.withValues(alpha: selected ? 0.95 : 0.6),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            numero,
            style: const TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 14,
            child: sinDatos
                ? Icon(Icons.refresh_rounded, size: 13, color: Colors.white.withValues(alpha: 0.8))
                : Text(
                    tercera ?? '',
                    style: TextStyle(
                      color: lleno && tercera == 'Lleno'
                          ? MonacoColors.warning.withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );

    final chip = Semantics(
      button: enabled,
      selected: selected,
      label: '$abrev $numero${tercera != null ? ', $tercera' : ''}${sinDatos ? ', sin datos, tocá para reintentar' : ''}',
      child: Opacity(opacity: opacity, child: box),
    );

    if (onTap == null) return chip;
    return LiquidTapEffect(
      onTap: onTap!,
      scaleTo: 0.94,
      borderRadius: BorderRadius.circular(18),
      child: chip,
    );
  }
}
