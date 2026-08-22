import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../../data/booking_models.dart';
import '../../data/fechas.dart';
import '../../providers/booking_provider.dart';
import 'day_strip.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Derivación de la grilla (réplica de slot-step.tsx §6.e)
// ═══════════════════════════════════════════════════════════════════════════

enum Franja { manana, tarde, noche }

extension FranjaX on Franja {
  String get label => switch (this) {
        Franja.manana => 'Mañana',
        Franja.tarde => 'Tarde',
        Franja.noche => 'Noche',
      };
  IconData get icon => switch (this) {
        Franja.manana => Icons.wb_twilight_rounded,
        Franja.tarde => Icons.wb_sunny_rounded,
        Franja.noche => Icons.nightlight_round,
      };
}

Franja franjaDe(String hhmm) {
  final m = Fechas.minutesOf(hhmm);
  if (m < 13 * 60) return Franja.manana;
  if (m < 18 * 60) return Franja.tarde;
  return Franja.noche;
}

class SlotGridData {
  /// Grupos con al menos un horario libre.
  final List<SlotGroup> conCupo;

  /// Filtro efectivo (null si no hay o se ignoró).
  final String? filtro;

  /// El barbero filtrado no atiende ese día: se ignora el filtro y se avisa.
  final String? filtroIgnoradoNombre;

  /// Una entrada por HORA (el primer barbero que la ofrece), ordenadas.
  final List<SlotSelection> entradas;

  /// Barbero que se muestra en la tarjeta y si la promesa es segura.
  final SlotGroup? barberoMostrado;
  final bool esSeguro;

  const SlotGridData({
    required this.conCupo,
    required this.filtro,
    required this.filtroIgnoradoNombre,
    required this.entradas,
    required this.barberoMostrado,
    required this.esSeguro,
  });

  Map<Franja, List<SlotSelection>> get porFranja {
    final out = <Franja, List<SlotSelection>>{};
    for (final e in entradas) {
      out.putIfAbsent(franjaDe(e.time), () => []).add(e);
    }
    return out;
  }
}

SlotGridData computeSlotGrid(BookingWizardState state) {
  final outcome = state.currentOutcome;
  final groups = (outcome != null && outcome.ok) ? outcome.groups : const <SlotGroup>[];
  final conCupo = groups.where((g) => g.hasCupo).toList();

  String? filtro = state.staffFilter;
  String? ignoradoNombre;
  if (filtro != null && !conCupo.any((g) => g.staffId == filtro)) {
    // El filtrado no atiende ese día (o no tiene cupo): se muestran todos.
    if (outcome != null && outcome.ok) {
      final nombre = state.bootstrap?.staff
          .where((s) => s.id == filtro)
          .map((s) => s.fullName)
          .firstOrNull;
      ignoradoNombre = nombre ?? 'Ese barbero';
    }
    filtro = null;
  }

  final fuente = filtro == null ? conCupo : conCupo.where((g) => g.staffId == filtro).toList();
  final porHora = <String, SlotSelection>{};
  for (final g in fuente) {
    for (final s in g.available) {
      porHora.putIfAbsent(
        s.time,
        () => SlotSelection(
          time: s.time,
          staffId: g.staffId,
          staffName: g.staffName,
          staffAvatarUrl: g.staffAvatarUrl,
        ),
      );
    }
  }
  final entradas = porHora.values.toList()
    ..sort((a, b) => Fechas.minutesOf(a.time).compareTo(Fechas.minutesOf(b.time)));

  SlotGroup? barberoDelSlot;
  final sel = state.selectedSlot;
  if (sel != null) {
    barberoDelSlot = conCupo.where((g) => g.staffId == sel.staffId).firstOrNull;
  }
  SlotGroup? barberoUnico;
  if (filtro != null) {
    barberoUnico = conCupo.where((g) => g.staffId == filtro).firstOrNull;
  } else if (conCupo.length == 1) {
    barberoUnico = conCupo.first;
  }
  final mostrado = barberoDelSlot ?? barberoUnico ?? conCupo.firstOrNull;
  final esSeguro = barberoDelSlot != null || barberoUnico != null;

  return SlotGridData(
    conCupo: conCupo,
    filtro: filtro,
    filtroIgnoradoNombre: ignoradoNombre,
    entradas: entradas,
    barberoMostrado: mostrado,
    esSeguro: esSeguro,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Paso 2 — "¿Cuándo te viene bien?"
// ═══════════════════════════════════════════════════════════════════════════

class SlotStep extends StatelessWidget {
  final BookingWizardState state;
  final ValueChanged<String> onSelectDate;
  final ValueChanged<String> onRetryDate;
  final ValueChanged<SlotSelection> onSelectSlot;
  final VoidCallback onElegirBarbero;

  const SlotStep({
    super.key,
    required this.state,
    required this.onSelectDate,
    required this.onRetryDate,
    required this.onSelectSlot,
    required this.onElegirBarbero,
  });

  @override
  Widget build(BuildContext context) {
    final boot = state.bootstrap!;
    final date = state.selectedDate;
    final grid = computeSlotGrid(state);
    final loading = state.loadingCurrent || state.currentOutcome == null;
    final outcome = state.currentOutcome;
    final staff = boot.staff;
    final walkIn = boot.walkInStaff;
    final puedeElegirBarbero = grid.conCupo.length > 1 || staff.length > 1 || walkIn.isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  '¿Cuándo te viene bien?',
                  style: TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    height: 1.1,
                  ),
                ),
              ),
              if (date != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 8),
                  child: Text(
                    Fechas.mesLargo(Fechas.parseDate(date), now: boot.nowFromServer),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ).liquidEnter(index: 0),
        const SizedBox(height: 14),
        DayStrip(
          days: state.windowDays,
          today: boot.serverToday,
          enabledDays: state.enabledDays,
          selected: date,
          fullDates: state.fullDates,
          unknownDates: state.unknownDates,
          onSelect: onSelectDate,
        ).liquidEnter(index: 1),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (date != null)
                Text(
                  Fechas.fechaLargaDeStr(date),
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              const SizedBox(height: 12),

              // ── Tarjeta "quién te atiende" ───────────────────────────
              if (!loading && grid.barberoMostrado != null) ...[
                _QuienTeAtiende(
                  grupo: grid.barberoMostrado!,
                  esSeguro: grid.esSeguro,
                  staff: staff.where((s) => s.id == grid.barberoMostrado!.staffId).firstOrNull,
                  dayOfWeek: date == null ? null : Fechas.dayOfWeek(date),
                  filtroActivo: grid.filtro != null,
                  mostrarBoton: puedeElegirBarbero,
                  onElegir: onElegirBarbero,
                ),
                const SizedBox(height: 12),
              ] else if (!loading && (staff.isNotEmpty || walkIn.isNotEmpty)) ...[
                LiquidPill(
                  onTap: onElegirBarbero,
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Ver barberos y sus horarios',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (grid.filtroIgnoradoNombre != null && !loading) ...[
                _Aviso(
                  text: '${grid.filtroIgnoradoNombre} no toma turnos ese día. Te mostramos los horarios de todos.',
                ),
                const SizedBox(height: 12),
              ],

              // ── Grilla / estados ─────────────────────────────────────
              if (loading)
                const _GrillaEsqueleto()
              else if (outcome != null && !outcome.ok)
                _ErrorMotor(
                  message: outcome.error!,
                  onRetry: date == null ? null : () => onRetryDate(date),
                )
              else if (grid.entradas.isEmpty)
                _SinHorarios(
                  date: date,
                  scanning: state.scanning,
                  scanFailed: state.scanFailed,
                  suggestions: state.suggestions,
                  onSelectDate: onSelectDate,
                )
              else
                _Grilla(
                  porFranja: grid.porFranja,
                  selected: state.selectedSlot,
                  onSelect: onSelectSlot,
                ),
            ],
          ),
        ).liquidEnter(index: 2),
      ],
    );
  }
}

// ── Tarjeta "Te atiende X" / "Posiblemente te atienda X" ───────────────────

class _QuienTeAtiende extends StatelessWidget {
  final SlotGroup grupo;
  final bool esSeguro;
  final PublicStaff? staff;
  final int? dayOfWeek;
  final bool filtroActivo;
  final bool mostrarBoton;
  final VoidCallback onElegir;

  const _QuienTeAtiende({
    required this.grupo,
    required this.esSeguro,
    required this.staff,
    required this.dayOfWeek,
    required this.filtroActivo,
    required this.mostrarBoton,
    required this.onElegir,
  });

  String get _detalle {
    final s = staff;
    if (s != null && dayOfWeek != null) {
      final rangos = s.windowsFor(dayOfWeek!);
      if (rangos.isNotEmpty) return 'Da turnos de ${Fechas.textoRangos(rangos)}';
      if (s.days.isNotEmpty) return 'Toma turnos ${Fechas.textoDias(s.days)}';
    }
    return 'Según el horario que elijas';
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      borderRadius: 20,
      tint: esSeguro ? MonacoColors.monacoGreen : Colors.white,
      tintOpacity: esSeguro ? 0.10 : 0.08,
      pressable: false,
      showVignette: false,
      child: Row(
        children: [
          LiquidAvatar(
            imageUrl: grupo.staffAvatarUrl,
            name: grupo.staffName,
            size: 46,
            tint: esSeguro ? MonacoColors.monacoGreen : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esSeguro ? 'TE ATIENDE' : 'POSIBLEMENTE TE ATIENDA',
                  style: TextStyle(
                    color: (esSeguro ? MonacoColors.monacoGreen : Colors.white).withValues(alpha: 0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  grupo.staffName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _detalle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (mostrarBoton) ...[
            const SizedBox(width: 8),
            LiquidPill(
              onTap: onElegir,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Text(
                filtroActivo ? 'Cambiar' : 'Elegir barbero',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Grilla por franjas ─────────────────────────────────────────────────────

class _Grilla extends StatelessWidget {
  final Map<Franja, List<SlotSelection>> porFranja;
  final SlotSelection? selected;
  final ValueChanged<SlotSelection> onSelect;

  const _Grilla({required this.porFranja, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 400 ? 4 : 3;
        const gap = 8.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final f in Franja.values)
              if ((porFranja[f] ?? const []).isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Row(
                    children: [
                      Icon(f.icon, size: 14, color: Colors.white.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Text(
                        f.label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final e in porFranja[f]!)
                      SizedBox(
                        width: w,
                        child: LiquidChip(
                          key: ValueKey(e.key),
                          label: e.time,
                          selected: selected?.key == e.key,
                          expand: true,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          fontSize: 14.5,
                          onTap: () => onSelect(e),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
          ],
        );
      },
    );
  }
}

class _GrillaEsqueleto extends StatelessWidget {
  const _GrillaEsqueleto();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Buscando horarios disponibles',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LiquidSkeleton(height: 70, radius: 20),
          const SizedBox(height: 14),
          const LiquidSkeleton.line(width: 90),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 400 ? 4 : 3;
            final w = (c.maxWidth - 8.0 * (cols - 1)) / cols;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < cols * 2; i++)
                  LiquidSkeleton(width: w, height: 44, radius: 14),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ErrorMotor extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorMotor({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: MonacoColors.destructive.withValues(alpha: 0.12),
        border: Border.all(color: MonacoColors.destructive.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: MonacoColors.destructive),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            LiquidPill(
              onTap: onRetry,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String text;
  const _Aviso({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: MonacoColors.warning.withValues(alpha: 0.10),
        border: Border.all(color: MonacoColors.warning.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: MonacoColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SinHorarios extends StatelessWidget {
  final String? date;
  final bool scanning;
  final bool scanFailed;
  final List<String> suggestions;
  final ValueChanged<String> onSelectDate;

  const _SinHorarios({
    required this.date,
    required this.scanning,
    required this.scanFailed,
    required this.suggestions,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      borderRadius: 22,
      tintOpacity: 0.07,
      pressable: false,
      showVignette: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 0.8),
                ),
                child: Icon(Icons.event_busy_rounded, size: 18, color: Colors.white.withValues(alpha: 0.85)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  date == null ? 'No quedan horarios' : 'No quedan horarios ese día',
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            date == null
                ? 'Elegí un día para ver los horarios disponibles.'
                : 'Los turnos del ${Fechas.fechaLargaDeStr(date!)} ya están todos tomados.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          if (scanning)
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  'Buscando los próximos días…',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else if (suggestions.isNotEmpty) ...[
            Text(
              'PRÓXIMOS DÍAS CON LUGAR',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in suggestions)
                  LiquidChip(
                    label: Fechas.fechaCortaDeStr(d),
                    leading: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                    onTap: () => onSelectDate(d),
                  ),
              ],
            ),
          ] else if (scanFailed)
            Text(
              'No pudimos consultar los próximos días. Probá de nuevo en un momento.',
              style: TextStyle(
                color: MonacoColors.warning.withValues(alpha: 0.95),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            )
          else
            Text(
              'Probá con otro día de la tira de arriba.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
