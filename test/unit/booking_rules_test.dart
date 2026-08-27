import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:monaco_mobile/features/appointments/data/booking_models.dart';
import 'package:monaco_mobile/features/appointments/presentation/widgets/slot_step.dart';
import 'package:monaco_mobile/features/appointments/providers/booking_provider.dart';

/// Reglas del wizard que la app REPLICA del turnero web (no del motor: el
/// motor vive en el dashboard). Todo puro: ventana de fechas (§6.a), días
/// habilitados, duración total, y la derivación de la grilla (§6.e): una
/// entrada por hora, el primer barbero que la ofrece, filtro ignorado con
/// aviso y la promesa "Te atiende" / "Posiblemente te atienda".
void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_AR');
  });

  const tz = 'America/Argentina/Buenos_Aires';

  group('ventana de fechas (réplica de ventana.ts)', () {
    test('antes de las 12:00 AR el último día se descarta (doble lectura)', () {
      // 08:00 AR del 20/8 → el motor en UTC compara 04/09 12:00Z contra
      // 20/8 11:00Z + 15 d = 04/09 11:00Z y lo rechaza. La tira no lo ofrece.
      final dias = diasDeVentana(
        today: '2026-08-20',
        maxAdvanceDays: 15,
        nowUtc: DateTime.utc(2026, 8, 20, 11, 0),
        tz: tz,
      );
      expect(dias.first, '2026-08-20');
      expect(dias.last, '2026-09-03');
      expect(dias.length, 15);
    });

    test('pasadas las 12:00 AR entran los max_advance_days + 1 días', () {
      final dias = diasDeVentana(
        today: '2026-08-20',
        maxAdvanceDays: 15,
        nowUtc: DateTime.utc(2026, 8, 20, 16, 0),
        tz: tz,
      );
      expect(dias.length, 16);
      expect(dias.last, '2026-09-04');
    });

    test('fechaDentroDeVentana exige que las DOS lecturas pasen', () {
      // 10:00 AR = 13:00Z: la lectura UTC (12:00Z) pasa, la de la sucursal
      // (15:00Z) no → se descarta igual. Mejor un día menos que uno que el
      // server rechaza.
      expect(
        fechaDentroDeVentana(
          dateStr: '2026-09-04',
          maxAdvanceDays: 15,
          nowUtc: DateTime.utc(2026, 8, 20, 13, 0),
          tz: tz,
        ),
        isFalse,
      );
      expect(
        fechaDentroDeVentana(
          dateStr: '2026-09-03',
          maxAdvanceDays: 15,
          nowUtc: DateTime.utc(2026, 8, 20, 13, 0),
          tz: tz,
        ),
        isTrue,
      );
    });

    test('proximosDias salta los días no habilitados y corta en n', () {
      final ventana = diasDeVentana(
        today: '2026-08-20',
        maxAdvanceDays: 15,
        nowUtc: DateTime.utc(2026, 8, 20, 16, 0),
        tz: tz,
      );
      // 20/8 es jueves; el domingo 23/8 no está habilitado.
      expect(
        proximosDias('2026-08-20', const [1, 2, 3, 4, 5, 6], ventana),
        ['2026-08-21', '2026-08-22', '2026-08-24'],
      );
      expect(proximosDias('2026-09-04', const [1, 2, 3, 4, 5, 6], ventana), isEmpty);
    });
  });

  BookingBootstrap boot({List<Map<String, dynamic>>? staff, List<Map<String, dynamic>>? services}) {
    return BookingBootstrap.fromJson({
      'server_today': '2026-08-20',
      'server_now': '2026-08-20T13:00:00Z',
      'branch': {
        'id': 'b1',
        'name': 'Rondeau',
        'slug': 'rondeau',
        'timezone': tz,
        'operation_mode': 'hybrid',
      },
      'bookable': true,
      'settings': {
        'max_advance_days': 15,
        'appointment_days': [1, 2, 3, 4, 5, 6],
        'slot_interval_minutes': 15,
        'cancellation_min_hours': 2,
        'lead_time_minutes': 30,
        'buffer_minutes': 0,
      },
      'branding': {'logo_url': null, 'welcome_message': null},
      'services': services ??
          [
            {'id': 'svc1', 'name': 'Corte', 'price': 12000, 'duration_minutes': 45, 'booking_mode': 'both'},
            {'id': 'svc2', 'name': 'Barba', 'price': 6000, 'duration_minutes': null, 'booking_mode': 'both'},
          ],
      'staff': staff ??
          [
            {
              'id': 's1',
              'full_name': 'Fabri',
              'avatar_url': null,
              'days': [2, 4],
              'windows': {
                '2': [
                  {'start': '10:00', 'end': '13:00'},
                  {'start': '16:00', 'end': '19:00'},
                ],
              },
            },
            {'id': 's2', 'full_name': 'Simón', 'avatar_url': null, 'days': [3], 'windows': {}},
          ],
      'walk_in_staff': [
        {'id': 'w1', 'full_name': 'Nico', 'avatar_url': null},
      ],
      'client': {'first_name': 'Nacho', 'last_name': 'B', 'phone': '3512125249', 'upcoming': null},
    });
  }

  group('BookingWizardState — derivados', () {
    test('enabledDays = configurados ∩ días de algún barbero; si queda vacío, los configurados', () {
      final conStaff = BookingWizardState(bootstrap: boot());
      expect(conStaff.enabledDays, [2, 3, 4]);

      final sinStaff = BookingWizardState(bootstrap: boot(staff: const []));
      expect(sinStaff.enabledDays, [1, 2, 3, 4, 5, 6]);
    });

    test('duración total suma servicios; uno sin duración cuenta el snap (igual que el motor)', () {
      final s = BookingWizardState(bootstrap: boot(), selectedServiceIds: const ['svc1', 'svc2']);
      expect(s.totalDuration, 45 + 15);
      expect(s.totalPrice, 18000);
      expect(s.selectedServices.map((x) => x.name), ['Corte', 'Barba']);
    });

    test('el orden de selección manda: [0] es el servicio principal', () {
      final s = BookingWizardState(bootstrap: boot(), selectedServiceIds: const ['svc2', 'svc1']);
      expect(s.selectedServices.first.id, 'svc2');
    });

    test('primerDiaHabilitado es el primer día de la tira con barbero', () {
      final s = BookingWizardState(bootstrap: boot());
      // 20/8 es jueves (4) → habilitado de entrada.
      expect(s.primerDiaHabilitado, '2026-08-20');
    });

    test('windows del barbero se leen por día', () {
      final fabri = boot().staff.first;
      expect(fabri.windowsFor(2).length, 2);
      expect(fabri.windowsFor(4), isEmpty);
    });
  });

  group('BookingWizardState — los tres pasos del wizard', () {
    // Desde ago/2026 la sucursal es el paso 1: la app no guarda ninguna, así
    // que reservar SIEMPRE empieza eligiendo dónde.
    test('pickBranch es el paso 1 y se llama "Sucursal"', () {
      const s = BookingWizardState(phase: WizardPhase.pickBranch);
      expect(s.stepIndex, 1);
      expect(s.stepLabel, 'Sucursal');
    });

    test('services es el paso 2', () {
      const s = BookingWizardState(phase: WizardPhase.services);
      expect(s.stepIndex, 2);
      expect(s.stepLabel, 'Servicio');
    });

    test('slot es el paso 3', () {
      const s = BookingWizardState(phase: WizardPhase.slot);
      expect(s.stepIndex, 3);
      expect(s.stepLabel, 'Día y horario');
    });

    test('loading y failed no inventan un paso: caen en el 1', () {
      expect(const BookingWizardState(phase: WizardPhase.loading).stepIndex, 1);
      expect(const BookingWizardState(phase: WizardPhase.failed).stepIndex, 1);
    });

    test('copyWith(bootstrap: null) SÍ borra el bootstrap (centinela _unset)',
        () {
      // De esto depende que "atrás" desde Servicios devuelva el título del
      // header a "Reservar turno" en vez de dejar la sucursal anterior.
      final conBoot = const BookingWizardState().copyWith(
        phase: WizardPhase.services,
        slug: 'rondeau',
      );
      final volvio = conBoot.copyWith(
        phase: WizardPhase.pickBranch,
        bootstrap: null,
        slug: '',
      );
      expect(volvio.bootstrap, isNull);
      expect(volvio.slug, '');
      expect(volvio.phase, WizardPhase.pickBranch);
    });
  });

  group('computeSlotGrid (réplica de slot-step.tsx §6.e)', () {
    SlotGroup g(String id, String name, List<(String, bool)> slots) => SlotGroup(
          staffId: id,
          staffName: name,
          slots: [for (final s in slots) SlotItem(time: s.$1, available: s.$2)],
        );

    final g1 = g('s1', 'Fabri', [('10:00', true), ('10:15', false), ('11:00', true)]);
    final g2 = g('s2', 'Simón', [('10:00', true), ('10:15', true), ('18:00', true)]);

    BookingWizardState base({String? filtro, SlotSelection? slot, List<SlotGroup>? groups}) =>
        BookingWizardState(
          phase: WizardPhase.slot,
          slug: 'rondeau',
          bootstrap: boot(),
          selectedServiceIds: const ['svc1'],
          selectedDate: '2026-08-25',
          slotsByDate: {'2026-08-25': SlotsOutcome.ok(groups ?? [g1, g2])},
          staffFilter: filtro,
          selectedSlot: slot,
        );

    test('una entrada por HORA, se queda el primer barbero que la ofrece', () {
      final grid = computeSlotGrid(base());
      expect(grid.entradas.map((e) => '${e.time}@${e.staffId}'), [
        '10:00@s1',
        '10:15@s2',
        '11:00@s1',
        '18:00@s2',
      ]);
      expect(grid.porFranja[Franja.manana]!.length, 3);
      expect(grid.porFranja[Franja.noche]!.length, 1);
      expect(grid.porFranja.containsKey(Franja.tarde), isFalse);
    });

    test('sin hora elegida y con dos barberos → "Posiblemente te atienda" el primero', () {
      final grid = computeSlotGrid(base());
      expect(grid.esSeguro, isFalse);
      expect(grid.barberoMostrado?.staffId, 's1');
      expect(grid.filtroIgnoradoNombre, isNull);
    });

    test('con hora elegida la promesa es segura y es el barbero de esa hora', () {
      final sel = SlotSelection(time: '10:15', staffId: 's2', staffName: 'Simón');
      final grid = computeSlotGrid(base(slot: sel));
      expect(grid.esSeguro, isTrue);
      expect(grid.barberoMostrado?.staffId, 's2');
    });

    test('filtro de barbero: sólo sus horas y la promesa es segura', () {
      final grid = computeSlotGrid(base(filtro: 's2'));
      expect(grid.filtro, 's2');
      expect(grid.entradas.map((e) => e.time), ['10:00', '10:15', '18:00']);
      expect(grid.entradas.every((e) => e.staffId == 's2'), isTrue);
      expect(grid.esSeguro, isTrue);
    });

    test('el filtrado no tiene cupo ese día → se ignora el filtro y se avisa con su nombre', () {
      final sinCupo = g('s1', 'Fabri', [('10:00', false)]);
      final grid = computeSlotGrid(base(filtro: 's1', groups: [sinCupo, g2]));
      expect(grid.filtro, isNull);
      expect(grid.filtroIgnoradoNombre, 'Fabri');
      expect(grid.entradas.map((e) => e.time), ['10:00', '10:15', '18:00']);
      // Queda un solo barbero con cupo → la promesa vuelve a ser segura.
      expect(grid.esSeguro, isTrue);
      expect(grid.barberoMostrado?.staffId, 's2');
    });

    test('un día con error del motor no arma grilla (sin datos ≠ lleno)', () {
      final s = base().copyWith(
        slotsByDate: {'2026-08-25': const SlotsOutcome.failed('No pudimos leer la disponibilidad.')},
      );
      final grid = computeSlotGrid(s);
      expect(grid.entradas, isEmpty);
      expect(grid.conCupo, isEmpty);
      expect(s.currentOutcome!.ok, isFalse);
      expect(s.currentOutcome!.hasCupo, isFalse);
    });

    test('franjas: Mañana < 13:00, Tarde 13:00–17:59, Noche >= 18:00', () {
      expect(franjaDe('12:59'), Franja.manana);
      expect(franjaDe('13:00'), Franja.tarde);
      expect(franjaDe('17:59'), Franja.tarde);
      expect(franjaDe('18:00'), Franja.noche);
    });
  });
}
